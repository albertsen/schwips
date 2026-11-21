import SwiftUI
import SchwipsCore

/// The design's colours: one burgundy accent for selection and primary
/// buttons, gold stars, tinted chips. Each has a dark variant.
enum Theme {
    static let accent = Color(light: 0x7A2232, dark: 0xD9707F)
    static let star = Color(light: 0x9A6B0C, dark: 0xE2B04A)
    static let starEmpty = Color(light: 0xCFC7BE, dark: 0x5C544D)
    static let error = Color(light: 0xB3261E, dark: 0xFF8A80)
    static let success = Color(light: 0x1E5E36, dark: 0x7FCB97)
    static let typeLabel = Color(light: 0x8A5A0B, dark: 0xD9A85A)

    static func chip(_ color: WineColor) -> (background: Color, foreground: Color) {
        switch color {
        case .white: (Color(light: 0xECEAE6, dark: 0x3A3733), Color(light: 0x4E4943, dark: 0xD8D3CC))
        case .red: (Color(light: 0xF6D5D5, dark: 0x4A2020), Color(light: 0x8E1F1F, dark: 0xF2A8A8))
        case .rose: (Color(light: 0xF7D9E7, dark: 0x4A2236), Color(light: 0x8A1D4F, dark: 0xF0A8C8))
        case .orange: (Color(light: 0xFBE3CC, dark: 0x4A3018), Color(light: 0x9A3F0A, dark: 0xF5C08A))
        }
    }

    static let ready = (Color(light: 0xDDEFE3, dark: 0x1F3D2A), Color(light: 0x1E5E36, dark: 0x9FDDB3))
    static let notReady = (Color(light: 0xF8E1D9, dark: 0x4A2A1F), Color(light: 0x8A2E14, dark: 0xF2B39C))
    static let neutral = (Color(light: 0xECE8E3, dark: 0x3A3733), Color(light: 0x4A433D, dark: 0xD8D3CC))
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        #if os(macOS)
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
        #else
        self.init(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
        #endif
    }
}

#if os(macOS)
extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
#else
extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
#endif

/// A small rounded tag: colour, readiness, "Not in stock".
struct Chip: View {
    var text: String
    var colors: (Color, Color)
    var inverted = false

    var body: some View {
        Text(verbatim: text)
            .font(.caption)
            .padding(.horizontal, 7)
            .padding(.vertical, 1)
            .background(Capsule().fill(inverted ? Color.white.opacity(0.18) : colors.0))
            .foregroundStyle(inverted ? Color.white : colors.1)
    }
}

/// The wine's readiness chip for this year, or nothing.
struct ReadinessChip: View {
    let wine: Wine
    var inverted = false

    var body: some View {
        let year = Day.currentYear()
        if wine.isReady(in: year) {
            Chip(text: String(localized: "chip.readyToDrink", defaultValue: "Ready to Drink"), colors: Theme.ready, inverted: inverted)
        } else if wine.isNotYetReady(in: year) {
            Chip(text: String(localized: "chip.notReadyYet", defaultValue: "Not Ready Yet"), colors: Theme.notReady, inverted: inverted)
        }
    }
}

/// An image from stored JPEG bytes.
struct StoredImage: View {
    let data: Data?

    var body: some View {
        #if os(macOS)
        if let data, let image = NSImage(data: data) {
            Image(nsImage: image).resizable()
        } else {
            placeholder
        }
        #else
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image).resizable()
        } else {
            placeholder
        }
        #endif
    }

    private var placeholder: some View {
        Image(systemName: "photo").resizable().scaledToFit().padding(20).foregroundStyle(.tertiary)
    }
}
