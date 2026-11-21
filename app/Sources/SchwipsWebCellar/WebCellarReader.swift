import Foundation
import SQLite3
import SchwipsCore

/// Reads the SvelteKit web app's cellar from `data/schwips.db`, read-only.
/// The file is never written: it is opened with `SQLITE_OPEN_READONLY`.
public enum WebCellarReader {
    public struct Failure: LocalizedError, Sendable {
        public let message: String
        public var errorDescription: String? { message }
    }

    /// The counts the Welcome sheet shows before copying.
    public struct Counts: Equatable, Sendable {
        public var wines: Int
        public var bottles: Int
        public var photos: Int
    }

    public static func counts(at url: URL) throws(Failure) -> Counts {
        let db = try Database(url)
        return Counts(
            wines: try db.count("wines"),
            bottles: try db.count("bottles"),
            photos: try db.count("photos")
        )
    }

    public static func read(at url: URL) throws(Failure) -> WebCellar {
        let db = try Database(url)
        var aliases: [Int: [String]] = [:]
        try db.each("SELECT grape_id, alias FROM grape_aliases ORDER BY id") { row in
            aliases[row.int(0) ?? 0, default: []].append(row.text(1) ?? "")
        }
        var grapeNames: [Int: String] = [:]
        var grapes: [WebCellar.GrapeRow] = []
        try db.each("SELECT id, name, color FROM grapes ORDER BY id") { row in
            let id = row.int(0) ?? 0
            let name = row.text(1) ?? ""
            grapeNames[id] = name
            grapes.append(WebCellar.GrapeRow(name: name, color: row.text(2), aliases: aliases[id] ?? []))
        }
        var wines: [WebCellar.WineRow] = []
        try db.each("""
            SELECT id, producer, name, vintage, wine_type, color, sweetness, quality_level, region, country,
                   appellation, vineyard, abv, residual_sugar_gl, acidity_gl, drink_from, drink_until, description,
                   food_pairing, serving_temp_c, closure, is_organic, is_vegan, external_links, extra_data,
                   data_sources, import_confidence, rating, wine_signature, created_at, updated_at
            FROM wines ORDER BY id
            """) { row in
            var wine = WebCellar.WineRow(
                id: row.int(0) ?? 0, producer: row.text(1) ?? "", signature: row.text(28) ?? "",
                createdAt: row.date(29), updatedAt: row.date(30)
            )
            wine.name = row.text(2)
            wine.vintage = row.int(3)
            wine.wineType = row.text(4)
            wine.color = row.text(5)
            wine.sweetness = row.text(6)
            wine.qualityLevel = row.text(7)
            wine.region = row.text(8)
            wine.country = row.text(9)
            wine.appellation = row.text(10)
            wine.vineyard = row.text(11)
            wine.abv = row.double(12)
            wine.residualSugar = row.double(13)
            wine.acidity = row.double(14)
            wine.drinkFrom = row.int(15)
            wine.drinkUntil = row.int(16)
            wine.description = row.text(17)
            wine.foodPairing = row.text(18)
            wine.servingTemp = row.text(19)
            wine.closure = row.text(20)
            wine.isOrganic = row.int(21).map { $0 != 0 }
            wine.isVegan = row.int(22).map { $0 != 0 }
            wine.externalLinksJSON = row.text(23)
            wine.extraDataJSON = row.text(24)
            wine.dataSourcesJSON = row.text(25)
            wine.importConfidence = row.double(26)
            wine.rating = row.int(27)
            wines.append(wine)
        }
        var wineGrapes: [WebCellar.WineGrapeRow] = []
        try db.each("SELECT wine_id, grape_id, label_name, percentage FROM wine_grapes ORDER BY rowid") { row in
            guard let name = grapeNames[row.int(1) ?? 0] else { return }
            wineGrapes.append(WebCellar.WineGrapeRow(
                wineID: row.int(0) ?? 0, grapeName: name, labelName: row.text(2), percentage: row.double(3)
            ))
        }
        var bottles: [WebCellar.BottleRow] = []
        try db.each("""
            SELECT wine_id, bottle_size_ml, location, purchase_date, purchase_price, purchase_vendor, current_value,
                   status, consumed_date, personal_rating, created_at, updated_at
            FROM bottles ORDER BY id
            """) { row in
            var bottle = WebCellar.BottleRow(
                wineID: row.int(0) ?? 0, sizeML: row.int(1) ?? 750, status: row.text(7) ?? "in_stock",
                createdAt: row.date(10), updatedAt: row.date(11)
            )
            bottle.location = row.text(2)
            bottle.purchaseDate = row.text(3)
            bottle.purchasePrice = row.double(4)
            bottle.vendor = row.text(5)
            bottle.price = row.double(6)
            bottle.drunkOn = row.text(8)
            bottle.personalRating = row.int(9)
            bottles.append(bottle)
        }
        var photos: [WebCellar.PhotoRow] = []
        try db.each("SELECT wine_id, file_path, is_primary, created_at FROM photos ORDER BY id") { row in
            photos.append(WebCellar.PhotoRow(
                wineID: row.int(0) ?? 0, path: row.text(1) ?? "", isPrimary: (row.int(2) ?? 0) != 0, createdAt: row.date(3)
            ))
        }
        return WebCellar(wines: wines, wineGrapes: wineGrapes, grapes: grapes, bottles: bottles, photos: photos)
    }
}

// MARK: SQLite

private final class Database {
    private var handle: OpaquePointer?

    init(_ url: URL) throws(WebCellarReader.Failure) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw WebCellarReader.Failure(message: String(localized: "data/schwips.db is missing."))
        }
        let status = sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READONLY, nil)
        guard status == SQLITE_OK else {
            let reason = handle.map { String(cString: sqlite3_errmsg($0)) } ?? String(cString: sqlite3_errstr(status))
            sqlite3_close(handle)
            handle = nil
            throw WebCellarReader.Failure(message: String(localized: "data/schwips.db can’t be read: \(reason)."))
        }
    }

    deinit {
        sqlite3_close(handle)
    }

    func count(_ table: String) throws(WebCellarReader.Failure) -> Int {
        var count = 0
        try each("SELECT COUNT(*) FROM \(table)") { count = $0.int(0) ?? 0 }
        return count
    }

    func each(_ sql: String, _ body: (Row) -> Void) throws(WebCellarReader.Failure) {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            throw failure()
        }
        defer { sqlite3_finalize(statement) }
        while true {
            let step = sqlite3_step(statement)
            if step == SQLITE_DONE { return }
            guard step == SQLITE_ROW else { throw failure() }
            body(Row(statement: statement))
        }
    }

    private func failure() -> WebCellarReader.Failure {
        let reason = String(cString: sqlite3_errmsg(handle))
        return WebCellarReader.Failure(message: String(localized: "data/schwips.db can’t be read: \(reason)."))
    }

    struct Row {
        let statement: OpaquePointer?

        private func isNull(_ index: Int32) -> Bool { sqlite3_column_type(statement, index) == SQLITE_NULL }

        func int(_ index: Int32) -> Int? {
            isNull(index) ? nil : Int(sqlite3_column_int64(statement, index))
        }

        func double(_ index: Int32) -> Double? {
            isNull(index) ? nil : sqlite3_column_double(statement, index)
        }

        func text(_ index: Int32) -> String? {
            guard !isNull(index), let pointer = sqlite3_column_text(statement, index) else { return nil }
            return String(cString: pointer)
        }

        /// Unix seconds; now when missing.
        func date(_ index: Int32) -> Date {
            int(index).map { Date(timeIntervalSince1970: TimeInterval($0)) } ?? .now
        }
    }
}
