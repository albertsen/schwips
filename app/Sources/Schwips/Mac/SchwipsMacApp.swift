import AppKit
import SwiftData
import SwiftUI
import SchwipsCore

// Mac-only: the app, its main window, the photo viewer, Settings and menus.

@main
struct SchwipsMacApp: App {
    @State private var app: AppState

    init() {
        let url: URL
        let container: ModelContainer
        do {
            url = try CellarLocation.storeURL()
            FileHandle.standardError.write(Data("cellar: \(url.path)\n".utf8))
            container = try CellarContainer.make(at: url)
        } catch {
            StoreFailureAlert.show(path: CellarLocation.folder().path, error: error)
        }
        _app = State(initialValue: AppState(container: container))
    }

    var body: some Scene {
        // One window, so one undo stack.
        Window("Schwips", id: "main") {
            RootView()
                .restoresWindowFrame(named: "main")
                .environment(app)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    app.activated()
                }
        }
        .modelContainer(app.container)
        .commands {
            SidebarCommands()
            CellarCommands()
        }

        WindowGroup(id: PhotoTarget.windowID, for: PhotoTarget.self) { $target in
            PhotoViewer(target: $target)
                .environment(app)
        }
        .modelContainer(app.container)
        .defaultSize(width: 760, height: 760)

        Settings {
            SettingsView()
                .environment(app)
                .modelContainer(app.container)
        }
    }
}

/// ⌘F focuses the search; the Wine menu acts on the selected wine.
struct CellarCommands: Commands {
    @FocusedValue(\.windowModel) private var model
    @FocusedValue(\.selectedWine) private var wine

    var body: some Commands {
        CommandGroup(after: .textEditing) {
            Button("Find") { model?.isSearchFocused = true }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(model == nil)
        }
        CommandMenu("Wine") {
            Button("Mark as Drunk…") { model?.markDrunkRequest += 1 }
                .keyboardShortcut("d", modifiers: .command)
                .disabled(wine == nil || wine?.inStockCount == 0)
            Button("Add Bottle") {
                guard let wine, let context = wine.modelContext else { return }
                // The window's undo manager: the main window is key when the menu acts.
                _ = try? Cellar(context: context, undoManager: NSApp.keyWindow?.undoManager).addBottle(to: wine)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(wine == nil)
            Button("Show Photos") { model?.showPhotosRequest += 1 }
                .disabled(wine?.photos?.isEmpty ?? true)
        }
    }
}

/// A store that can't open: say where and why, then quit. Never deletes it.
enum StoreFailureAlert {
    static func show(path: String, error: any Error) -> Never {
        let alert = NSAlert()
        alert.messageText = String(localized: "Schwips can’t open its cellar")
        alert.informativeText = "\(path)\n\n\(error.localizedDescription)"
        alert.alertStyle = .critical
        alert.runModal()
        exit(1)
    }
}
