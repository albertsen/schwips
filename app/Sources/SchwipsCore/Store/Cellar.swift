import Foundation
import SwiftData

/// The operations that change the cellar. Views call these instead of setting
/// model properties, so the rules hold in one place and are tested without a
/// display.
@MainActor
public struct Cellar {
    public let context: ModelContext
    /// The window's undo manager. The context's own stays nil: SwiftData's undo
    /// reverts values in memory without marking the context dirty on macOS
    /// 27.2, so an undone change would never be saved. `Cellar` records and
    /// restores changes itself, from value snapshots.
    public let undoManager: UndoManager?

    public init(context: ModelContext, undoManager: UndoManager? = nil) {
        self.context = context
        self.undoManager = undoManager
    }

    // MARK: Undo and saving

    /// Runs one user action as one undo step: snapshot, mutate, save, snapshot,
    /// and register closures that write the difference back. Operations
    /// validate before they mutate; on a failure nothing is saved or registered.
    @discardableResult
    func change<T>(_ name: LocalizedStringResource, _ body: () throws -> T) throws -> T {
        let before = CellarSnapshot.capture(context)
        let result: T
        do {
            result = try body()
            try save()
        } catch {
            context.rollback()
            throw error
        }
        guard undoManager != nil else { return result }
        let after = CellarSnapshot.capture(context)
        let undo = CellarDiff(from: after, to: before)
        let redo = CellarDiff(from: before, to: after)
        if !undo.isEmpty || !redo.isEmpty {
            register(name, undo: undo, redo: redo)
        }
        return result
    }

    private func register(_ name: LocalizedStringResource, undo: CellarDiff, redo: CellarDiff) {
        guard let manager = undoManager else { return }
        manager.beginUndoGrouping()
        // The closure holds the manager weakly: the manager owns the closure.
        manager.registerUndo(withTarget: context) { [weak manager] context in
            MainActor.assumeIsolated {
                let cellar = Cellar(context: context, undoManager: manager)
                undo.apply(to: context)
                do {
                    try cellar.save()
                } catch {
                    context.rollback()
                    FileHandle.standardError.write(Data("undo: \(error)\n".utf8))
                }
                cellar.register(name, undo: redo, redo: undo)
            }
        }
        manager.setActionName(String(localized: name))
        manager.endUndoGrouping()
    }

    public func save() throws {
        if context.hasChanges { try context.save() }
    }

    // MARK: Lookups

    public func wines() throws -> [Wine] {
        try context.fetch(FetchDescriptor<Wine>())
    }

    public func wine(number: Int) throws -> Wine? {
        var descriptor = FetchDescriptor<Wine>(predicate: #Predicate { $0.number == number })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// The next free wine number: one above the highest.
    public func nextWineNumber() throws -> Int {
        var descriptor = FetchDescriptor<Wine>(sortBy: [SortDescriptor(\.number, order: .reverse)])
        descriptor.fetchLimit = 1
        return (try context.fetch(descriptor).first?.number ?? 0) + 1
    }

    public func isEmpty() throws -> Bool {
        try context.fetchCount(FetchDescriptor<Wine>()) == 0
    }

    public func grapes() throws -> [Grape] {
        try context.fetch(FetchDescriptor<Grape>())
    }
}
