import Foundation
import SQLite3
import Testing
@testable import SchwipsCore
@testable import SchwipsWebCellar

/// A web app database built from its Drizzle migrations (fixtures), with sample rows.
@MainActor
struct WebCellarTests {
    private func makeDatabase() throws -> URL {
        let folder = try temporaryFolder()
        let url = folder.appending(path: "schwips.db")
        var db: OpaquePointer?
        #expect(sqlite3_open(url.path, &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        // The web app's two Drizzle migrations, kept as fixtures after the web
        // app was removed: the database the copy reads has this schema.
        for migration in ["web-schema-0000.sql", "web-schema-0001.sql"] {
            let sql = try String(contentsOf: fixtureURL(migration), encoding: .utf8)
            #expect(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK, "\(migration)")
        }
        let rows = """
        INSERT INTO grapes (id, name, color) VALUES (1, 'Grauburgunder', 'white'), (2, 'Riesling', 'white');
        INSERT INTO grape_aliases (grape_id, alias) VALUES (1, 'Pinot Grigio');
        INSERT INTO wines (id, producer, name, vintage, wine_type, color, rating, wine_signature, data_sources, created_at, updated_at)
          VALUES (12, 'Diel', 'Eierfels', 2023, 'wine', 'white', 4, 'stale', '{"producer":"label"}', 1700000000, 1700000000),
                 (38, 'San Silvestro', NULL, 2020, 'wine', 'red', NULL, 'x', NULL, 1700000000, 1700000000);
        INSERT INTO wine_grapes (wine_id, grape_id, label_name) VALUES (12, 2, NULL), (38, 1, 'Pinot Grigio');
        INSERT INTO bottles (wine_id, status, current_value, consumed_date) VALUES
          (12, 'in_stock', 26.0, NULL), (12, 'consumed', 26.0, '2026-11-14'), (38, 'in_stock', 18.0, NULL);
        INSERT INTO photos (wine_id, file_path, is_primary) VALUES (12, '12/IMG_1.jpeg', 1), (12, '12/IMG_2.jpeg', 0);
        """
        #expect(sqlite3_exec(db, rows, nil, nil, nil) == SQLITE_OK)
        return url
    }

    @Test func copiesWithNumbersDrunkBottlesRatingsAndFreshSignatures() throws {
        let url = try makeDatabase()
        #expect(try WebCellarReader.counts(at: url) == .init(wines: 2, bottles: 3, photos: 2))
        let web = try WebCellarReader.read(at: url)
        let cellar = try makeCellar()
        let photo = try PhotoShrinker.shrinkNow(makeJPEG(width: 20, height: 20))
        let outcome = try cellar.copyWebCellar(web, photos: ["12/IMG_1.jpeg": photo])
        #expect(outcome == WebCopyOutcome(wines: 2, bottles: 3, photos: 1, missingPhotos: 1))

        let diel = try #require(try cellar.wine(number: 12))
        #expect(diel.rating == 4)
        #expect(diel.inStockCount == 1)
        #expect(diel.drunkBottles.first.map { CellarFormatting(locale: Locale(identifier: "de_DE")).day($0.drunkOn!) } == "14.11.2026")
        #expect(diel.dataSources["producer"] == .label)
        #expect(diel.signature == Signature.compute(diel.signatureInput))
        #expect(diel.orderedPhotos.first?.isPrimary == true)
        #expect(try cellar.wine(number: 38)?.grapeDisplayNames == ["Pinot Grigio"])
        #expect(try cellar.nextWineNumber() == 39)
        #expect(throws: ImportError.self) { try cellar.copyWebCellar(web, photos: [:]) }
    }

    @Test func notADatabase() throws {
        let url = try temporaryFolder().appending(path: "schwips.db")
        try Data("hello".utf8).write(to: url)
        #expect(throws: WebCellarReader.Failure.self) { try WebCellarReader.read(at: url) }
    }
}

/// Opt-in: `SCHWIPS_WEB_RUNTIME=<runtime folder>` copies the real web cellar
/// (read-only) into an in-memory store, with every photo shrunk.
@MainActor
struct RealWebCellarTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["SCHWIPS_WEB_RUNTIME"] != nil))
    func copiesTheRealCellar() async throws {
        let runtime = URL(fileURLWithPath: ProcessInfo.processInfo.environment["SCHWIPS_WEB_RUNTIME"]!)
        let start = Date.now
        let web = try WebCellarReader.read(at: runtime.appending(path: "data/schwips.db"))
        var photos: [String: PhotoShrinker.Result] = [:]
        try await withThrowingTaskGroup(of: (String, PhotoShrinker.Result?).self) { group in
            for photo in web.photos {
                let url = runtime.appending(path: "photos/\(photo.path)")
                group.addTask {
                    guard let data = try? Data(contentsOf: url) else { return (photo.path, nil) }
                    return (photo.path, try await PhotoShrinker.shrink(data))
                }
            }
            for try await (path, result) in group { if let result { photos[path] = result } }
        }
        let cellar = try makeCellar()
        let outcome = try cellar.copyWebCellar(web, photos: photos)
        let bytes = photos.values.reduce(0) { $0 + $1.image.count }
        print("copied \(outcome) in \(Int(Date.now.timeIntervalSince(start))) s, photos \(bytes / 1_000_000) MB")
        #expect(outcome.wines == web.wines.count)
        #expect(outcome.bottles == web.bottles.count)
        for wine in try cellar.wines() {
            #expect(wine.signature == Signature.compute(wine.signatureInput))
        }
    }
}
