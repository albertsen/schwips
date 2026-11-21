import CoreGraphics
import Foundation
import ImageIO
import SwiftData
import UniformTypeIdentifiers
@testable import SchwipsCore

@MainActor
func makeCellar(undo: Bool = false) throws -> Cellar {
    let container = try CellarContainer.inMemory()
    let context = ModelContext(container)
    context.autosaveEnabled = false
    return Cellar(context: context, undoManager: undo ? UndoManager() : nil)
}

/// A wine with `inStock` bottles in stock and `drunk` drunk ones.
@MainActor
@discardableResult
func addWine(
    _ cellar: Cellar, number: Int, producer: String, name: String? = nil, vintage: Int? = nil,
    color: WineColor? = .white, type: WineType? = .wine, price: Double? = nil, rating: Int? = nil,
    drink: ClosedRange<Int>? = nil, grapes: [(String, String?)] = [], inStock: Int = 1, drunk: Int = 0,
    created: Date = .now
) throws -> Wine {
    let wine = Wine(number: number, producer: producer)
    cellar.context.insert(wine)
    wine.name = name
    wine.vintage = vintage
    wine.color = color
    wine.wineType = type
    wine.rating = rating
    wine.drinkFrom = drink?.lowerBound
    wine.drinkUntil = drink?.upperBound
    wine.createdAt = created
    for (position, (canonical, label)) in grapes.enumerated() {
        let grape = try cellar.grapes().first { $0.name == canonical } ?? {
            let grape = Grape(name: canonical, colorRaw: "white")
            cellar.context.insert(grape)
            return grape
        }()
        let link = WineGrape()
        link.position = position
        link.labelName = label
        cellar.context.insert(link)
        link.wine = wine
        link.grape = grape
    }
    for index in 0..<(inStock + drunk) {
        let bottle = Bottle()
        cellar.context.insert(bottle)
        bottle.wine = wine
        bottle.price = price
        bottle.createdAt = created.addingTimeInterval(TimeInterval(index))
        if index >= inStock {
            bottle.status = .consumed
            bottle.drunkOn = Day.parse(iso: "2026-10-0\(index - inStock + 1)")
        }
    }
    wine.signature = Signature.compute(wine.signatureInput)
    try cellar.context.save()
    return wine
}

/// A small JPEG of the given size, for import and shrink tests.
func makeJPEG(width: Int, height: Int, orientation: Int = 1) -> Data {
    let space = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(CGColor(red: 0.5, green: 0.1, blue: 0.2, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let image = context.makeImage()!
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: orientation] as CFDictionary)
    CGImageDestinationFinalize(destination)
    return data as Data
}

func pixelSize(of data: Data) -> (width: Int, height: Int) {
    let source = CGImageSourceCreateWithData(data as CFData, nil)!
    let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as! [CFString: Any]
    return (properties[kCGImagePropertyPixelWidth] as! Int, properties[kCGImagePropertyPixelHeight] as! Int)
}

func fixtureURL(_ name: String) -> URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent().appending(path: "Fixtures/\(name)")
}

func temporaryFolder() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "schwips-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
