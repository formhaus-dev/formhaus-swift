import SwiftUI

extension Palette {
    public static let light = Palette(
        text: Color(hex: 0x18181B), textMuted: Color(hex: 0x5F5F68), border: Color(hex: 0xD4D4D8), inputBorder: Color(hex: 0xB1B8C2),
        borderHover: Color(hex: 0xA1A1AA), control: Color(hex: 0x71717A), error: Color(hex: 0xC0352D), errorHover: Color(hex: 0x9E2A23),
        background: Color(hex: 0xFFFFFF), backgroundDisabled: Color(hex: 0xF4F4F5), backgroundHover: Color(hex: 0xF6F6F7),
        primary: Color(hex: 0x5502FB), onPrimary: Color(hex: 0xFFFFFF), secondaryBorder: Color(hex: 0xD4D4D8),
        scrim: Color(hex: 0x141416, opacity: 0.32), shadow: Color(hex: 0x141416, opacity: 0.2), focus: Color(hex: 0x5502FB),
        primaryHover: Color(hex: 0x4602CE), primarySoft: Color(hex: 0xF0E8FF), errorSoft: Color(hex: 0xFAEFEE),
        inputBorderHover: Color(hex: 0x8E959F))
    static let lightIncreased: Palette = {
        var palette = light
        palette.border = Color(hex: 0x84848D)
        palette.inputBorder = Color(hex: 0x84848D)
        palette.borderHover = Color(hex: 0x5F5F68)
        palette.secondaryBorder = Color(hex: 0x84848D)
        palette.inputBorderHover = Color(hex: 0x5F5F68)
        return palette
    }()
    public static let dark = Palette(
        text: Color(hex: 0xECECEE), textMuted: Color(hex: 0xA8A8B3), border: Color(hex: 0x3A3A41), inputBorder: Color(hex: 0x444B53),
        borderHover: Color(hex: 0x5A5A63), control: Color(hex: 0x80808B), error: Color(hex: 0xF2736A), errorHover: Color(hex: 0xF6958E),
        background: Color(hex: 0x18181C), backgroundDisabled: Color(hex: 0x232328), backgroundHover: Color(hex: 0x212126),
        primary: Color(hex: 0x7C4DFF), onPrimary: Color(hex: 0xFFFFFF), secondaryBorder: Color(hex: 0x3A3A41),
        scrim: Color(hex: 0x000000, opacity: 0.55), shadow: Color(hex: 0x000000, opacity: 0.6), focus: Color(hex: 0x7C4DFF),
        primaryHover: Color(hex: 0x9068FF), primarySoft: Color(hex: 0x211D30), errorSoft: Color(hex: 0x291F22),
        inputBorderHover: Color(hex: 0x5E656D))
    static let darkIncreased: Palette = {
        var palette = dark
        palette.border = Color(hex: 0x73737D)
        palette.inputBorder = Color(hex: 0x73737D)
        palette.borderHover = Color(hex: 0x9A9AA5)
        palette.secondaryBorder = Color(hex: 0x73737D)
        palette.inputBorderHover = Color(hex: 0x9A9AA5)
        return palette
    }()
}

extension ColorMixes {
    static let light = ColorMixes(primaryHover: 0.82, primaryHoverWith: Color(hex: 0x000000), primarySoft: 0.09, errorSoft: 0.08)
    static let dark = ColorMixes(primaryHover: 0.85, primaryHoverWith: Color(hex: 0xFFFFFF), primarySoft: 0.09, errorSoft: 0.08)
}

extension Typography {
    static let headingStep: CGFloat = 2
    static let titleStep: CGFloat = 5
    static let fine = Typography(body: 15, small: 13, heading: 17, title: 20)
    static let coarse: Typography = {
        var typography = fine
        typography.body = 17
        typography.small = 15
        typography.heading = 19
        typography.title = 22
        return typography
    }()
}

extension Spacing {
    static let regular = Spacing(s1: 4, s2: 6, s3: 8, s4: 10, s5: 12, s6: 14, s7: 16, s8: 18, s9: 20, s10: 24, gap: 28, cardPadding: 24)
    static let compact: Spacing = {
        var spacing = regular
        spacing.cardPadding = 16
        return spacing
    }()
}

extension Radii {
    static let standard = Radii(control: 10)
}

extension Controls {
    static let fine = Controls(height: 46, iconButton: 32, star: 32, optionImageWidth: 200)
    static let coarse: Controls = {
        var controls = fine
        controls.star = 40
        return controls
    }()
}

enum RaisedShadow {
    static let x: CGFloat = 0
    static let y: CGFloat = 2
    static let blur: CGFloat = 8
}
