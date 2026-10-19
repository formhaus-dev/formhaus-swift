import SwiftUI

public struct Palette: Sendable {
    public var text: Color
    public var textMuted: Color
    public var border: Color
    public var inputBorder: Color
    public var borderHover: Color
    public var control: Color
    public var error: Color
    public var errorHover: Color
    public var background: Color
    public var backgroundDisabled: Color
    public var backgroundHover: Color
    public var primary: Color
    public var onPrimary: Color
    public var secondaryBorder: Color
    public var scrim: Color
    public var shadow: Color
    public var focus: Color?
    public var primaryHover: Color?
    public var primarySoft: Color?
    public var errorSoft: Color?
    public var inputBorderHover: Color?

    public init(
        text: Color = Color(hex: 0x18181B), textMuted: Color = Color(hex: 0x5F5F68), border: Color = Color(hex: 0xD4D4D8),
        inputBorder: Color = Color(hex: 0x8E8E93), borderHover: Color = Color(hex: 0xA1A1AA), control: Color = Color(hex: 0x71717A),
        error: Color = Color(hex: 0xC0352D),
        errorHover: Color = Color(hex: 0x9E2A23), background: Color = .white, backgroundDisabled: Color = Color(hex: 0xF4F4F5),
        backgroundHover: Color = Color(hex: 0xF6F6F7), primary: Color = Color(hex: 0x5502FB), onPrimary: Color = .white,
        secondaryBorder: Color = Color(hex: 0xD4D4D8), scrim: Color = Color(hex: 0x141416, opacity: 0.32),
        shadow: Color = Color(hex: 0x141416, opacity: 0.2)
    ) {
        self.text = text
        self.textMuted = textMuted
        self.border = border
        self.inputBorder = inputBorder
        self.borderHover = borderHover
        self.control = control
        self.error = error
        self.errorHover = errorHover
        self.background = background
        self.backgroundDisabled = backgroundDisabled
        self.backgroundHover = backgroundHover
        self.primary = primary
        self.onPrimary = onPrimary
        self.secondaryBorder = secondaryBorder
        self.scrim = scrim
        self.shadow = shadow
    }

    public static let light = Palette()

    public static let dark = Palette(
        text: Color(hex: 0xECECEE), textMuted: Color(hex: 0xA8A8B3), border: Color(hex: 0x3A3A41), inputBorder: Color(hex: 0x6B6B75),
        borderHover: Color(hex: 0x5A5A63),
        control: Color(hex: 0x80808B), error: Color(hex: 0xF2736A), errorHover: Color(hex: 0xF6958E), background: Color(hex: 0x18181C),
        backgroundDisabled: Color(hex: 0x232328), backgroundHover: Color(hex: 0x212126), primary: Color(hex: 0x7C4DFF),
        onPrimary: .white, secondaryBorder: Color(hex: 0x3A3A41), scrim: Color(hex: 0x000000, opacity: 0.55),
        shadow: Color(hex: 0x000000, opacity: 0.6)
    )
}

public struct ResolvedPalette: Sendable {
    public let text: Color
    public let textMuted: Color
    public let border: Color
    public let inputBorder: Color
    public let inputBorderHover: Color
    public let borderHover: Color
    public let control: Color
    public let error: Color
    public let errorHover: Color
    public let errorSoft: Color
    public let background: Color
    public let backgroundDisabled: Color
    public let backgroundHover: Color
    public let primary: Color
    public let onPrimary: Color
    public let primaryHover: Color
    public let primarySoft: Color
    public let primaryOnSoft: Color
    public let primaryDisabled: Color
    public let secondaryBorder: Color
    public let focus: Color
    public let scrim: Color
    public let shadow: Color

    init(_ palette: Palette, dark: Bool, environment: EnvironmentValues) {
        let background = palette.background.resolve(in: environment)
        let primary = palette.primary.resolve(in: environment)
        let error = palette.error.resolve(in: environment)
        text = palette.text
        textMuted = palette.textMuted
        border = palette.border
        inputBorder = palette.inputBorder
        inputBorderHover =
            palette.inputBorderHover ?? Color(mix(palette.text.resolve(in: environment), palette.inputBorder.resolve(in: environment), 0.4))
        borderHover = palette.borderHover
        control = palette.control
        self.error = palette.error
        errorHover = palette.errorHover
        errorSoft = palette.errorSoft ?? Color(mix(error, background, 0.08))
        self.background = palette.background
        backgroundDisabled = palette.backgroundDisabled
        backgroundHover = palette.backgroundHover
        self.primary = palette.primary
        onPrimary = palette.onPrimary
        primaryHover = palette.primaryHover ?? Color(mix(primary, dark ? .white : .black, dark ? 0.85 : 0.82))
        primarySoft = palette.primarySoft ?? Color(mix(primary, background, 0.09))
        primaryOnSoft = dark ? Color(mix(primary, .white, 0.6)) : palette.primary
        primaryDisabled = Color(mix(primary, background, dark ? 0.3 : 0.1))
        secondaryBorder = palette.secondaryBorder
        focus = palette.focus ?? palette.primary
        scrim = palette.scrim
        shadow = palette.shadow
    }
}

func mix(_ color: Color.Resolved, _ other: Color.Resolved, _ amount: Float) -> Color.Resolved {
    let rest = 1 - amount
    return Color.Resolved(
        red: color.red * amount + other.red * rest, green: color.green * amount + other.green * rest,
        blue: color.blue * amount + other.blue * rest, opacity: 1
    )
}

extension Color.Resolved {
    fileprivate static let white = Color.Resolved(red: 1, green: 1, blue: 1)
    fileprivate static let black = Color.Resolved(red: 0, green: 0, blue: 0)
}

extension Color {
    @usableFromInline
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
