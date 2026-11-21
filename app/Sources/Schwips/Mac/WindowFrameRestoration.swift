import AppKit
import SwiftUI

// Mac-only. SwiftUI restores a window's frame only through state restoration,
// which macOS skips when "Close windows when quitting an application" is on
// (the default), and its own placement centres the window on the main display
// when the window is first shown, after the view arrived in it. So the frame
// is kept under a key of our own, which SwiftUI never writes, and put back
// when the window first becomes key, which is after SwiftUI's placement.
//
// The column widths have the same problem: SwiftUI saves the split view's
// frames but lays the columns out at their ideal widths at launch. So the
// widths of the sidebar and the list are saved here whenever the split view
// resizes them, and set on each new split view (at launch, and when the list
// switches between list and grid) and again after the frame is restored.

extension View {
    /// Restores the display, position and size of the window this view is in,
    /// and saves them whenever the window moves or resizes.
    func restoresWindowFrame(named name: String) -> some View {
        background(WindowFrameRestorer(key: "WindowFrame \(name)", fallbackKey: "NSWindow Frame \(name)"))
    }
}

private struct WindowFrameRestorer: NSViewRepresentable {
    let key: String
    /// SwiftUI's own autosave entry, read once when ours does not exist yet.
    let fallbackKey: String

    func makeNSView(context: Context) -> FrameView { FrameView(key: key, fallbackKey: fallbackKey) }
    func updateNSView(_ view: FrameView, context: Context) {}

    final class FrameView: NSView {
        private let key: String
        private let fallbackKey: String
        private var observed: NSWindow?
        /// False until the saved frame is applied, so SwiftUI's initial
        /// placement is never saved over it.
        private var restored = false
        private var tokens: [NSObjectProtocol] = []
        /// Split views that already got the saved widths.
        private var arrangedSplitViews = Set<ObjectIdentifier>()
        /// True while the saved widths are being applied, so that is not saved back.
        private var isApplyingWidths = false

        init(key: String, fallbackKey: String) {
            self.key = key
            self.fallbackKey = fallbackKey
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { nil }

        isolated deinit {
            tokens.forEach(NotificationCenter.default.removeObserver)
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window, window !== observed else { return }
            observed = window
            tokens.forEach(NotificationCenter.default.removeObserver)
            let center = NotificationCenter.default
            tokens = [
                center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.restore() }
                },
                center.addObserver(forName: NSWindow.didMoveNotification, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.save() }
                },
                center.addObserver(forName: NSWindow.didResizeNotification, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.save() }
                },
                center.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.save() }
                },
                // Any split view in the app; `splitViewResized` keeps the ones in this window.
                center.addObserver(forName: NSSplitView.didResizeSubviewsNotification, object: nil, queue: .main) { [weak self] note in
                    let splitView = note.object as? NSSplitView
                    MainActor.assumeIsolated { self?.splitViewResized(splitView) }
                },
            ]
            if window.isKeyWindow { restore() }
        }

        /// Once per window. The string is AppKit's frame descriptor, which also
        /// names the display; AppKit moves the frame onto a connected display
        /// if that one is gone.
        private func restore() {
            guard !restored, let window = observed else { return }
            let defaults = UserDefaults.standard
            if let saved = defaults.string(forKey: key) ?? defaults.string(forKey: fallbackKey) {
                window.setFrame(from: saved)
            }
            restored = true
            // The new window size may have moved the dividers.
            if let splitView = Self.columnSplitView(in: window.contentView) { applyWidths(to: splitView) }
        }

        // MARK: Column widths

        private static let sidebarKey = "sidebarWidth"
        private static let listKey = "listWidth"

        /// The NavigationSplitView's split view: vertical dividers, two or three columns.
        private static func columnSplitView(in view: NSView?) -> NSSplitView? {
            guard let view else { return nil }
            if let split = view as? NSSplitView, split.isVertical, (2...3).contains(split.arrangedSubviews.count) {
                return split
            }
            for subview in view.subviews {
                if let found = columnSplitView(in: subview) { return found }
            }
            return nil
        }

        private func splitViewResized(_ splitView: NSSplitView?) {
            guard let splitView, let window = observed, splitView.window === window, splitView.isVertical,
                  (2...3).contains(splitView.arrangedSubviews.count), !isApplyingWidths else { return }
            if arrangedSplitViews.insert(ObjectIdentifier(splitView)).inserted {
                applyWidths(to: splitView)
            } else if restored {
                saveWidths(of: splitView)
            }
        }

        /// Sets the sidebar's divider, then the list's, to the saved widths.
        private func applyWidths(to splitView: NSSplitView) {
            let defaults = UserDefaults.standard
            let columns = splitView.arrangedSubviews
            guard let sidebar = defaults.object(forKey: Self.sidebarKey) as? Double,
                  !splitView.isSubviewCollapsed(columns[0]) else { return }
            isApplyingWidths = true
            defer { isApplyingWidths = false }
            splitView.setPosition(sidebar, ofDividerAt: 0)
            if columns.count == 3, let list = defaults.object(forKey: Self.listKey) as? Double {
                splitView.setPosition(columns[0].frame.width + splitView.dividerThickness + list, ofDividerAt: 1)
            }
        }

        private func saveWidths(of splitView: NSSplitView) {
            let columns = splitView.arrangedSubviews
            let defaults = UserDefaults.standard
            // A collapsed or hidden sidebar keeps the width it had.
            if !splitView.isSubviewCollapsed(columns[0]), columns[0].frame.width > 0 {
                defaults.set(Double(columns[0].frame.width), forKey: Self.sidebarKey)
            }
            if columns.count == 3, columns[1].frame.width > 0 {
                defaults.set(Double(columns[1].frame.width), forKey: Self.listKey)
            }
        }

        // MARK: Frame

        private func save() {
            guard restored, let window = observed, !window.styleMask.contains(.fullScreen) else { return }
            UserDefaults.standard.set(window.frameDescriptor, forKey: key)
        }
    }
}
