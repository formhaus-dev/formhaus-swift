import SwiftUI
import Testing

@testable import FormhausUI

func luminance(_ color: Color) -> Double {
    let resolved = color.resolve(in: EnvironmentValues())
    func channel(_ value: Float) -> Double {
        let value = Double(value)
        return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * channel(resolved.red) + 0.7152 * channel(resolved.green) + 0.0722 * channel(resolved.blue)
}

func contrast(_ lhs: Color, _ rhs: Color) -> Double {
    let pair = [luminance(lhs), luminance(rhs)].sorted()
    return (pair[1] + 0.05) / (pair[0] + 0.05)
}

struct PaletteCheck {
    let name: String
    let ratio: Double
    let minimum: Double
}

func paletteChecks(_ palette: Palette, increased: Bool) -> [PaletteCheck] {
    let background = palette.background
    var checks = [
        PaletteCheck(name: "text", ratio: contrast(palette.text, background), minimum: increased ? 7 : 4.5),
        PaletteCheck(name: "muted", ratio: contrast(palette.textMuted, background), minimum: 4.5),
        PaletteCheck(name: "placeholder", ratio: contrast(palette.control, background), minimum: 4.5),
        PaletteCheck(name: "error", ratio: contrast(palette.error, background), minimum: 4.5),
        PaletteCheck(name: "primary", ratio: contrast(palette.primary, background), minimum: 3),
        PaletteCheck(name: "onPrimary", ratio: contrast(palette.onPrimary, palette.primary), minimum: 4.5),
    ]
    if increased { checks.append(PaletteCheck(name: "border", ratio: contrast(palette.border, background), minimum: 3)) }
    return checks
}

@Suite("Contrast")
struct ContrastTests {
    @Test(
        "palette text, errors and controls meet WCAG AA",
        arguments: [
            ("light", Palette.light, false), ("dark", Palette.dark, false), ("light increased", Palette.lightIncreased, true),
            ("dark increased", Palette.darkIncreased, true),
        ])
    func palettes(name: String, palette: Palette, increased: Bool) {
        for check in paletteChecks(palette, increased: increased) {
            #expect(check.ratio >= check.minimum, "\(name) \(check.name): \(check.ratio)")
        }
    }

    @Test("Increase Contrast picks the increased palettes")
    @MainActor
    func increased() {
        let tokens = FormhausTokens(theme: .standard, dark: false, typeSize: .large, reduceMotion: false, increasedContrast: true)
        #expect(luminance(tokens.colors.border) == luminance(Palette.lightIncreased.border))
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
