import FormhausUI
import SwiftUI

extension FormComponents {
    static let kiln = FormComponents.standard
        .field("text") { KilnTextField(context: $0) }
        .field("email") { KilnTextField(context: $0) }
        .field("radio") { KilnChoiceField(context: $0) }
        .field("multiselect") { KilnChoiceField(context: $0) }
        .field("scale") { KilnScaleField(context: $0) }
        .field("rating") { KilnRatingField(context: $0) }
        .section { KilnSection(context: $0) }
        .progress { KilnStepHeader(context: $0) }
        .actions { KilnActions(context: $0) }
}

extension FormhausTheme {
    static let kiln: FormhausTheme = {
        var theme = FormhausTheme.standard
        theme.light = Palette(
            text: Color(kiln: 0x2B2118), textMuted: Color(kiln: 0x76665A), border: Color(kiln: 0xDDCFBF),
            borderHover: Color(kiln: 0xB9A693), control: Color(kiln: 0x7A6A5C), error: Color(kiln: 0xB42318),
            errorHover: Color(kiln: 0x912018), background: Color(kiln: 0xFBF6EF), backgroundDisabled: Color(kiln: 0xF1E8DC),
            backgroundHover: Color(kiln: 0xF5EDE2), primary: Color(kiln: 0xB8502A), onPrimary: Color(kiln: 0xFFF8F1),
            secondaryBorder: Color(kiln: 0xDDCFBF))
        theme.dark = Palette(
            text: Color(kiln: 0xF3EAE0), textMuted: Color(kiln: 0xB8A898), border: Color(kiln: 0x463B31),
            borderHover: Color(kiln: 0x66574A), control: Color(kiln: 0x9C8B7C), error: Color(kiln: 0xFF8A80),
            errorHover: Color(kiln: 0xFFADA6), background: Color(kiln: 0x1D1712), backgroundDisabled: Color(kiln: 0x2A221B),
            backgroundHover: Color(kiln: 0x271F18), primary: Color(kiln: 0xE8825A), onPrimary: Color(kiln: 0x1D1712),
            secondaryBorder: Color(kiln: 0x463B31))
        theme.lightIncreased = theme.light
        theme.lightIncreased.textMuted = Color(kiln: 0x54463B)
        theme.lightIncreased.border = Color(kiln: 0x8A7766)
        theme.lightIncreased.control = Color(kiln: 0x5E4F43)
        theme.lightIncreased.primary = Color(kiln: 0x8F3A18)
        theme.darkIncreased = theme.dark
        theme.darkIncreased.textMuted = Color(kiln: 0xD9CBBD)
        theme.darkIncreased.border = Color(kiln: 0x8F7D6C)
        theme.darkIncreased.control = Color(kiln: 0xC4B3A3)
        theme.darkIncreased.primary = Color(kiln: 0xF4A07E)
        theme.radii.control = 22
        return theme
    }()
}

enum KilnType {
    static let title = Font.system(.title, design: .serif).weight(.semibold)
    static let heading = Font.system(.title3, design: .serif).weight(.semibold)
    static let label = Font.system(.subheadline, design: .rounded).weight(.semibold)
    static let body = Font.system(.body, design: .rounded)
    static let note = Font.system(.footnote, design: .rounded)
    static let eyebrow = Font.system(.caption, design: .rounded).weight(.bold)
}

extension Color {
    init(kiln hex: UInt32) {
        self.init(
            .sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}
