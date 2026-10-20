import SwiftUI
import Testing

@testable import FormhausUI

private let paletteTokens: [(KeyPath<Palette, Color> & Sendable, String)] = [
    (\.text, "color.text.default"), (\.textMuted, "color.text.muted"), (\.border, "color.border.default"),
    (\.inputBorder, "color.input.border"), (\.borderHover, "color.border.hover"), (\.control, "color.control.hover"),
    (\.error, "color.error.default"), (\.errorHover, "color.error.hover"), (\.background, "color.bg.default"),
    (\.backgroundDisabled, "color.bg.disabled"), (\.backgroundHover, "color.bg.hover"), (\.primary, "color.primary.default"),
    (\.onPrimary, "color.primary.text"), (\.secondaryBorder, "color.secondary.border"), (\.scrim, "color.scrim"),
    (\.shadow, "color.shadow"),
]

private let derivedTokens: [(KeyPath<Palette, Color?> & Sendable, String)] = [
    (\.focus, "color.border.focus"), (\.primaryHover, "color.primary.hover"), (\.primarySoft, "color.primary.soft"),
    (\.errorSoft, "color.error.soft"), (\.inputBorderHover, "color.input.border-hover"),
]

private func hex(_ color: Color) -> (hex: String, alpha: Double) {
    let resolved = color.resolve(in: EnvironmentValues())
    let channels = [resolved.red, resolved.green, resolved.blue].map { String(format: "%02x", Int(($0 * 255).rounded())) }
    return ("#" + channels.joined(), (Double(resolved.opacity) * 100).rounded() / 100)
}

private func expectColor(_ color: Color?, _ tokens: ResolvedTokens, _ path: String, _ context: String) throws {
    let expected = try tokens.color(path)
    let actual = hex(try #require(color, "\(context) \(path)"))
    #expect(actual.hex == expected.hex && actual.alpha == expected.alpha, "\(context) \(path)")
}

@Suite("Generated tokens match the DTCG source")
struct TokenSourceTests {
    static let palettes: [(String, [String: String], Palette)] = [
        ("light", ["theme": "light"], .light), ("dark", ["theme": "dark"], .dark),
        ("lightIncreased", ["theme": "light", "contrast": "more"], .lightIncreased),
        ("darkIncreased", ["theme": "dark", "contrast": "more"], .darkIncreased),
    ]

    @Test("palettes", arguments: palettes.indices)
    func palette(index: Int) throws {
        let (name, context, palette) = Self.palettes[index]
        let tokens = try ResolvedTokens(context)
        for (field, path) in paletteTokens { try expectColor(palette[keyPath: field], tokens, path, name) }
        for (field, path) in derivedTokens { try expectColor(palette[keyPath: field], tokens, path, name) }
    }

    @Test("Increase Contrast resolves to the contrast-more borders", arguments: [ColorScheme.light, .dark])
    func increased(scheme: ColorScheme) throws {
        let tokens = try ResolvedTokens(["theme": scheme == .dark ? "dark" : "light", "contrast": "more"])
        let palette = FormhausTheme.standard.palette(for: scheme, contrast: .increased)
        let borders = paletteTokens.filter { ["color.input.border", "color.border.default", "color.border.hover"].contains($0.1) }
        for (field, path) in borders { try expectColor(palette[keyPath: field], tokens, path, "\(scheme)") }
        try expectColor(palette.inputBorderHover, tokens, "color.input.border-hover", "\(scheme)")
    }

    @Test("colour mix rules", arguments: [("light", ColorMixes.light), ("dark", ColorMixes.dark)])
    func mixes(name: String, mixes: ColorMixes) throws {
        let tokens = try ResolvedTokens(["theme": name])
        let amounts: [(Float, String)] = [
            (mixes.primaryHover, "color.primary.hover"), (mixes.primarySoft, "color.primary.soft"), (mixes.errorSoft, "color.error.soft"),
        ]
        for (amount, path) in amounts {
            let mix = try #require(try tokens.extensions(path)["mix"] as? [String: Any])
            #expect(amount == (mix["amount"] as? Double).map(Float.init), "\(name) \(path)")
        }
        let with = try #require(try tokens.extensions("color.primary.hover")["mix"] as? [String: Any])["with"] as? String
        let partner = try tokens.color(String(try #require(with).dropFirst().dropLast()))
        #expect(hex(mixes.primaryHoverWith).hex == partner.hex)
    }

    @Test("pointer metrics", arguments: [("fine", Typography.fine, Controls.fine), ("coarse", Typography.coarse, Controls.coarse)])
    func pointer(name: String, typography: Typography, controls: Controls) throws {
        let tokens = try ResolvedTokens(["pointer": name])
        let values: [(CGFloat, String)] = [
            (typography.body, "font-size.default"), (typography.small, "font-size.small"), (typography.heading, "font-size.heading"),
            (typography.title, "font-size.title"), (controls.star, "star.size"), (controls.height, "control.height"),
            (controls.iconButton, "icon-button.size"), (controls.optionImageWidth, "option-image.width"),
        ]
        for (value, path) in values { #expect(Double(value) == (try tokens.dimension(path)), "\(name) \(path)") }
        let add = try #require(try tokens.extensions("font-size.heading")["add"] as? [String: Any])
        #expect(Double(Typography.headingStep) == (try ResolvedTokens.dimension(try #require(add["amount"]))))
    }

    @Test("width metrics", arguments: [("regular", Spacing.regular), ("compact", Spacing.compact)])
    func width(name: String, spacing: Spacing) throws {
        let tokens = try ResolvedTokens(["width": name])
        let steps = [
            spacing.s1, spacing.s2, spacing.s3, spacing.s4, spacing.s5, spacing.s6, spacing.s7, spacing.s8, spacing.s9, spacing.s10,
        ]
        for (index, value) in steps.enumerated() { #expect(Double(value) == (try tokens.dimension("space.\(index + 1)"))) }
        #expect(Double(spacing.gap) == (try tokens.dimension("gap")))
        #expect(Double(spacing.cardPadding) == (try tokens.dimension("card.padding")), "\(name)")
        #expect(Double(Radii.standard.control) == (try tokens.dimension("radius.default")))
    }

    @Test("raised shadow")
    func shadow() throws {
        let value = try #require(try ResolvedTokens().value("shadow.raised") as? [String: Any])
        #expect(Double(RaisedShadow.x) == (try ResolvedTokens.dimension(try #require(value["offsetX"]))))
        #expect(Double(RaisedShadow.y) == (try ResolvedTokens.dimension(try #require(value["offsetY"]))))
        #expect(Double(RaisedShadow.blur) == (try ResolvedTokens.dimension(try #require(value["blur"]))))
    }

    @Test("the pointer and touch themes use the pointer and width contexts")
    func themes() {
        #expect(
            FormhausTheme.pointer.typography.body == Typography.fine.body && FormhausTheme.touch.typography.body == Typography.coarse.body)
        #expect(FormhausTheme.pointer.spacing.cardPadding == Spacing.regular.cardPadding)
        #expect(FormhausTheme.touch.spacing.cardPadding == Spacing.compact.cardPadding)
        #expect(FormhausTheme.touch.controls.star == Controls.coarse.star)
    }
}
