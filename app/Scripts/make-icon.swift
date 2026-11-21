// Draws the app icon into an .iconset folder: a wine glass, half filled, on
// the design's burgundy, with a gold rim of light.
//
// Usage: swift Scripts/make-icon.swift <output.iconset>
// `make icon` runs it and turns the iconset into Resources/AppIcon.icns.
//
// The artwork is full-bleed and opaque: macOS masks a full-bleed icon to its
// own rounded square. Mac-only build tool, not part of the app.

import AppKit

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

let burgundy = color(0x7A2232)
let deep = color(0x4E1420)
let glass = color(0xF7F1EA)
let wine = color(0xB8384D)
let gold = color(0xE2B04A)

/// Coordinates follow a 100-unit grid with y pointing down.
func drawIcon(size: Int) -> NSBitmapImageRep? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let scale = CGFloat(size) / 100
    let transform = NSAffineTransform()
    transform.translateX(by: 0, yBy: CGFloat(size))
    transform.scaleX(by: scale, yBy: -scale)
    transform.concat()

    burgundy.setFill()
    NSRect(x: 0, y: 0, width: 100, height: 100).fill()
    deep.setFill()
    NSBezierPath(ovalIn: NSRect(x: 26, y: 80, width: 48, height: 8)).fill()

    // The bowl: a rounded cup from the rim down to the stem.
    let bowl = NSBezierPath()
    bowl.move(to: NSPoint(x: 31, y: 16))
    bowl.line(to: NSPoint(x: 69, y: 16))
    bowl.curve(to: NSPoint(x: 50, y: 56), controlPoint1: NSPoint(x: 72, y: 38), controlPoint2: NSPoint(x: 66, y: 56))
    bowl.curve(to: NSPoint(x: 31, y: 16), controlPoint1: NSPoint(x: 34, y: 56), controlPoint2: NSPoint(x: 28, y: 38))
    bowl.close()
    glass.withAlphaComponent(0.92).setFill()
    bowl.fill()

    // The wine fills the lower half of the bowl.
    NSGraphicsContext.saveGraphicsState()
    bowl.addClip()
    wine.setFill()
    NSRect(x: 20, y: 34, width: 60, height: 30).fill()
    NSGraphicsContext.restoreGraphicsState()

    // Stem and foot.
    glass.setFill()
    NSBezierPath(roundedRect: NSRect(x: 48, y: 55, width: 4, height: 25), xRadius: 2, yRadius: 2).fill()
    NSBezierPath(ovalIn: NSRect(x: 34, y: 78, width: 32, height: 6)).fill()

    if size >= 64 {
        gold.setStroke()
        let rim = NSBezierPath()
        rim.move(to: NSPoint(x: 31, y: 16))
        rim.line(to: NSPoint(x: 69, y: 16))
        rim.lineWidth = 1.6
        rim.lineCapStyle = .round
        rim.stroke()
        color(0xFFFFFF, alpha: 0.55).setStroke()
        let shine = NSBezierPath()
        shine.move(to: NSPoint(x: 36, y: 22))
        shine.curve(to: NSPoint(x: 40, y: 44), controlPoint1: NSPoint(x: 35, y: 30), controlPoint2: NSPoint(x: 36, y: 38))
        shine.lineWidth = 2
        shine.lineCapStyle = .round
        shine.stroke()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: swift make-icon.swift <output.iconset>\n".utf8))
    exit(64)
}
let output = URL(fileURLWithPath: arguments[1])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

for points in [16, 32, 128, 256, 512] {
    for factor in [1, 2] {
        let pixels = points * factor
        let name = factor == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        guard let rep = drawIcon(size: pixels), let png = rep.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("could not draw \(name)\n".utf8))
            exit(1)
        }
        try png.write(to: output.appendingPathComponent(name))
    }
}
