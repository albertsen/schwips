import SwiftUI

// Mac-only styles used by shared views, mapped onto iOS.

extension View {
    /// The Mac's compact date field; the compact picker on iOS.
    func fieldDatePickerStyle() -> some View {
        #if os(macOS)
        datePickerStyle(.field)
        #else
        datePickerStyle(.compact)
        #endif
    }

    /// A button drawn as a link on the Mac; borderless on iOS.
    func linkButtonStyle() -> some View {
        #if os(macOS)
        buttonStyle(.link)
        #else
        buttonStyle(.borderless)
        #endif
    }
}
