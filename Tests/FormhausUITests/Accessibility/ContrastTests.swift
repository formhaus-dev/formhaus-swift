import SwiftUI
import Testing

@testable import FormhausUI

func ratio(_ lhs: Color, _ rhs: Color) -> Double {
    contrastRatio(lhs.resolve(in: EnvironmentValues()), rhs.resolve(in: EnvironmentValues()))
}

func checkPalette(_ name: String, _ palette: Palette, increased: Bool) {
    let background = palette.background
    let checks: [(String, Double, Double)] = [
        ("text", ratio(palette.text, background), increased ? 7 : 4.5),
        ("muted", ratio(palette.textMuted, background), increased ? 7 : 4.5),
        ("placeholder", ratio(palette.control, background), 4.5),
        ("error", ratio(palette.error, background), 4.5),
        ("primary", ratio(palette.primary, background), increased ? 4.5 : 3),
        ("onPrimary", ratio(palette.onPrimary, palette.primary), 4.5),
    ]
    for (check, value, minimum) in checks {
        #expect(value >= minimum, "\(name) \(check): \(value)")
    }
    if increased { #expect(ratio(palette.border, background) >= 3, "\(name) border") }
}

private let forest: FormhausTheme = {
    var theme = FormhausTheme.standard
    theme.light = Palette(
        text: Color(hex: 0x1B2A1F), textMuted: Color(hex: 0x5B6B5F), border: Color(hex: 0xD6E2D9), control: Color(hex: 0x66766A),
        background: Color(hex: 0xF7FBF8), primary: Color(hex: 0x1E7A44))
    theme.dark = Palette(
        text: Color(hex: 0xE6F2E9), textMuted: Color(hex: 0x9DB2A3), border: Color(hex: 0x2E3D33), control: Color(hex: 0x8AA092),
        error: Color(hex: 0xFF8A80), background: Color(hex: 0x111A14), primary: Color(hex: 0x5BD08A), onPrimary: Color(hex: 0x0B1A10))
    return theme
}()

@Suite("Contrast")
struct ContrastTests {
    @Test("formhaus palettes meet WCAG AA, and Increase Contrast raises borders to 3:1", arguments: [ColorScheme.light, .dark])
    func standard(scheme: ColorScheme) {
        checkPalette("\(scheme)", FormhausTheme.standard.palette(for: scheme, contrast: .standard), increased: false)
        checkPalette("\(scheme) increased", FormhausTheme.standard.palette(for: scheme, contrast: .increased), increased: true)
    }

    @Test("a custom theme keeps its own colours under Increase Contrast", arguments: [ColorScheme.light, .dark])
    func custom(scheme: ColorScheme) {
        let increased = forest.palette(for: scheme, contrast: .increased)
        checkPalette("forest \(scheme) increased", increased, increased: true)
        let primary = increased.primary.resolve(in: EnvironmentValues())
        #expect(primary.green > primary.red && primary.green > primary.blue)
    }

    @Test("an explicit Increase Contrast palette wins over the derived one")
    func explicit() {
        var theme = forest
        theme.lightIncreased = Palette(primary: Color(hex: 0x0B4D27))
        #expect(ratio(theme.palette(for: .light, contrast: .increased).primary, Color(hex: 0x0B4D27)) < 1.01)
    }

    @Test("Reduce Motion turns animations off")
    @MainActor
    func reduceMotion() {
        let still = FormhausTokens(theme: .standard, dark: false, typeSize: .large, reduceMotion: true)
        let moving = FormhausTokens(theme: .standard, dark: false, typeSize: .large, reduceMotion: false)
        #expect(still.quick == nil && still.animation(0.3) == nil)
        #expect(moving.quick != nil)
    }
}
