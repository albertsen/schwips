import Foundation
import SchwipsCore

/// The texts a wine shows in several places.
@MainActor
enum WineText {
    /// "Diel Eierfels 2023".
    static func fullName(_ wine: Wine) -> String {
        [wine.producer, wine.name, wine.vintage.map(String.init)].compactMap { $0 }.joined(separator: " ")
    }

    /// "2023", or "NV" / "o. J." without a vintage.
    static func vintage(_ wine: Wine) -> String {
        wine.vintage.map(String.init) ?? String(localized: "NV", comment: "no vintage")
    }

    /// "WINE · Riesling · 2023" without the type, which is drawn on its own.
    static func grapesAndVintage(_ wine: Wine) -> String {
        ([wine.grapeDisplayNames.joined(separator: ", ")].filter { !$0.isEmpty } + [vintage(wine)])
            .joined(separator: " · ")
    }

    /// The row's third line: name or appellation (else region), then the tier.
    static func originLine(_ wine: Wine) -> String {
        var parts: [String] = []
        if let vineyard = wine.vineyard { parts.append(vineyard) }
        else if let appellation = wine.appellation { parts.append(appellation) }
        else if let region = wine.region { parts.append(region) }
        if let quality = wine.qualityLevel { parts.append(quality) }
        return parts.joined(separator: " · ")
    }

    /// The detail's line under the name: grapes · tier · region, country.
    static func detailLine(_ wine: Wine) -> String {
        var parts: [String] = []
        let grapes = wine.grapeDisplayNames.joined(separator: ", ")
        if !grapes.isEmpty { parts.append(grapes) }
        if let quality = wine.qualityLevel { parts.append(quality) }
        let place = [wine.region, wine.country].compactMap { $0 }.joined(separator: ", ")
        if !place.isEmpty { parts.append(place) }
        return parts.joined(separator: " · ")
    }

    /// "1 bottle" / "2 bottles".
    static func bottles(_ count: Int) -> String {
        String(localized: "\(count) bottles")
    }

    /// The hover text of a fact: where its value came from.
    static func provenance(_ source: Provenance?) -> String {
        switch source {
        case .label: String(localized: "From the label · Double-click to edit")
        case .research: String(localized: "From research · Double-click to edit")
        case .user: String(localized: "Entered by you · Double-click to edit")
        case nil: String(localized: "Double-click to edit")
        }
    }
}
