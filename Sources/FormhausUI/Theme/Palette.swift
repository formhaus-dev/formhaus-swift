import SwiftUI

public struct Palette: Sendable, Equatable {
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
        text: Color = Palette.light.text, textMuted: Color = Palette.light.textMuted, border: Color = Palette.light.border,
        inputBorder: Color = Palette.light.inputBorder, borderHover: Color = Palette.light.borderHover,
        control: Color = Palette.light.control, error: Color = Palette.light.error, errorHover: Color = Palette.light.errorHover,
        background: Color = Palette.light.background, backgroundDisabled: Color = Palette.light.backgroundDisabled,
        backgroundHover: Color = Palette.light.backgroundHover, primary: Color = Palette.light.primary,
        onPrimary: Color = Palette.light.onPrimary, secondaryBorder: Color = Palette.light.secondaryBorder,
        scrim: Color = Palette.light.scrim, shadow: Color = Palette.light.shadow, focus: Color? = nil, primaryHover: Color? = nil,
        primarySoft: Color? = nil, errorSoft: Color? = nil, inputBorderHover: Color? = nil
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
        self.focus = focus
        self.primaryHover = primaryHover
        self.primarySoft = primarySoft
        self.errorSoft = errorSoft
        self.inputBorderHover = inputBorderHover
    }
}

struct ColorMixes: Sendable {
    let primaryHover: Float
    let primaryHoverWith: Color
    let primarySoft: Float
    let errorSoft: Float
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
        let mixes = dark ? ColorMixes.dark : .light
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
        errorSoft = palette.errorSoft ?? Color(mix(error, background, mixes.errorSoft))
        self.background = palette.background
        backgroundDisabled = palette.backgroundDisabled
        backgroundHover = palette.backgroundHover
        self.primary = palette.primary
        onPrimary = palette.onPrimary
        primaryHover = palette.primaryHover ?? Color(mix(primary, mixes.primaryHoverWith.resolve(in: environment), mixes.primaryHover))
        primarySoft = palette.primarySoft ?? Color(mix(primary, background, mixes.primarySoft))
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
