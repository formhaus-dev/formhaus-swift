import FormhausUI
import SwiftUI
import Testing

@testable import FormhausDemo

private func ratio(_ lhs: Color, _ rhs: Color) -> Double {
    let values = [lhs, rhs].map { color -> Double in
        let resolved = color.resolve(in: EnvironmentValues())
        return Double(0.2126 * resolved.linearRed + 0.7152 * resolved.linearGreen + 0.0722 * resolved.linearBlue)
    }
    return (values.max().map { $0 + 0.05 } ?? 1) / (values.min().map { $0 + 0.05 } ?? 1)
}

@Suite("Kiln contrast")
struct KilnContrastTests {
    @Test(
        "Kiln text, errors and controls meet WCAG AA",
        arguments: [
            ("light", FormhausTheme.kiln.light, false), ("dark", FormhausTheme.kiln.dark, false),
            ("light increased", FormhausTheme.kiln.lightIncreased, true), ("dark increased", FormhausTheme.kiln.darkIncreased, true),
        ])
    func palette(name: String, palette: Palette, increased: Bool) {
        let checks: [(String, Double, Double)] = [
            ("text", ratio(palette.text, palette.background), increased ? 7 : 4.5),
            ("muted", ratio(palette.textMuted, palette.background), 4.5),
            ("muted on chip", ratio(palette.textMuted, palette.backgroundDisabled), 4.5),
            ("placeholder", ratio(palette.control, palette.background), 4.5),
            ("error", ratio(palette.error, palette.background), 4.5),
            ("on primary", ratio(palette.onPrimary, palette.primary), 4.5),
            ("primary", ratio(palette.primary, palette.background), 3),
        ]
        for (check, value, minimum) in checks {
            #expect(value >= minimum, "\(name) \(check): \(value)")
        }
        if increased { #expect(ratio(palette.border, palette.background) >= 3, "\(name) border") }
    }
}
