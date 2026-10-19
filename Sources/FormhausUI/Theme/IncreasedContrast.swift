import SwiftUI

extension FormhausTheme {
    public func palette(for colorScheme: ColorScheme, contrast: ColorSchemeContrast) -> Palette {
        var environment = EnvironmentValues()
        environment.colorScheme = colorScheme
        return palette(dark: colorScheme == .dark, increasedContrast: contrast == .increased, environment: environment)
    }

    func palette(dark: Bool, increasedContrast: Bool, environment: EnvironmentValues) -> Palette {
        let base = dark ? self.dark : light
        guard increasedContrast else { return base }
        return (dark ? darkIncreased : lightIncreased) ?? base.raisingContrast(in: environment)
    }
}

extension Palette {
    func raisingContrast(in environment: EnvironmentValues) -> Palette {
        let background = background.resolve(in: environment)
        let ink = text.resolve(in: environment)
        func raise(_ color: Color, to target: Double) -> Color {
            let base = color.resolve(in: environment)
            for step in 0...20 {
                let mixed = mix(ink, base, Float(step) / 20)
                if contrastRatio(mixed, background) >= target { return Color(mixed) }
            }
            return Color(ink)
        }
        var raised = self
        raised.textMuted = raise(textMuted, to: 7)
        raised.control = raise(control, to: 4.5)
        raised.border = raise(border, to: 3)
        raised.inputBorder = raise(inputBorder, to: 4.5)
        raised.borderHover = raise(borderHover, to: 4.5)
        raised.secondaryBorder = raise(secondaryBorder, to: 3)
        raised.error = raise(error, to: 4.5)
        raised.primary = raise(primary, to: 4.5)
        let fill = raised.primary.resolve(in: environment)
        if contrastRatio(onPrimary.resolve(in: environment), fill) < 4.5 {
            raised.onPrimary = contrastRatio(background, fill) >= contrastRatio(ink, fill) ? self.background : text
        }
        return raised
    }
}

func contrastRatio(_ lhs: Color.Resolved, _ rhs: Color.Resolved) -> Double {
    func luminance(_ color: Color.Resolved) -> Double {
        Double(0.2126 * color.linearRed + 0.7152 * color.linearGreen + 0.0722 * color.linearBlue)
    }
    let values = [luminance(lhs), luminance(rhs)].sorted()
    return (values[1] + 0.05) / (values[0] + 0.05)
}
