import Foundation
import SwiftData

/// Builds the `ModelContainer`. It never deletes, moves or overwrites an
/// existing store: when the store cannot be opened, the error goes to the
/// caller. Sync stays off explicitly, so the store never mirrors by itself.
public enum CellarContainer {
    public static var schema: Schema { Schema(versionedSchema: SchemaV2.self) }

    public static func make(at url: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, migrationPlan: SchwipsMigrationPlan.self, configurations: [configuration])
    }

    public static func inMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, migrationPlan: SchwipsMigrationPlan.self, configurations: [configuration])
    }
}

/// Where the cellar lives. `$SCHWIPS_HOME` replaces the folder, for agents and
/// manual tests, so the real cellar is never touched.
public enum CellarLocation {
    public static let storeFileName = "Schwips.store"

    /// `$SCHWIPS_HOME` if set, else `Application Support/Schwips/`, which the
    /// sandbox maps into the app's container.
    public static func folder(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let home = environment["SCHWIPS_HOME"], !home.isEmpty {
            return URL(fileURLWithPath: home, isDirectory: true)
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appending(path: "Library/Application Support", directoryHint: .isDirectory)
        return support.appending(path: "Schwips", directoryHint: .isDirectory)
    }

    /// `<folder>/Schwips.store`. Creates the folder when it is missing.
    public static func storeURL(environment: [String: String] = ProcessInfo.processInfo.environment) throws -> URL {
        let folder = folder(environment: environment)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appending(path: storeFileName, directoryHint: .notDirectory)
    }
}
