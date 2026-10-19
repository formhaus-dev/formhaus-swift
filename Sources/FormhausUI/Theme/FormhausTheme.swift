import SwiftUI

public struct Typography: Sendable {
    public var body: CGFloat
    public var small: CGFloat
    public var heading: CGFloat
    public var title: CGFloat
    public var design: Font.Design

    public init(body: CGFloat, small: CGFloat, heading: CGFloat? = nil, title: CGFloat? = nil, design: Font.Design = .default) {
        self.body = body
        self.small = small
        self.heading = heading ?? body + 2
        self.title = title ?? body + 5
        self.design = design
    }
}

public struct Spacing: Sendable {
    public var s1: CGFloat = 4
    public var s2: CGFloat = 6
    public var s3: CGFloat = 8
    public var s4: CGFloat = 10
    public var s5: CGFloat = 12
    public var s6: CGFloat = 14
    public var s7: CGFloat = 16
    public var s8: CGFloat = 18
    public var s9: CGFloat = 20
    public var s10: CGFloat = 24
    public var gap: CGFloat = 28
    public var cardPadding: CGFloat = 24

    public init() {}
}

public struct Radii: Sendable {
    public var control: CGFloat = 10
    public var indicator: CGFloat = 5

    public init() {}
}

public struct Controls: Sendable {
    public var height: CGFloat = 46
    public var hitTarget: CGFloat = 44
    public var iconButton: CGFloat = 32
    public var star: CGFloat
    public var indicator: CGFloat = 18
    public var optionImageWidth: CGFloat = 200
    public var textareaHeight: CGFloat = 112
    public var progressHeight: CGFloat = 4
    public var maxWidth: CGFloat = 640
    public var compactWidth: CGFloat = 480
    public var matrixWidth: CGFloat = 560

    public init(star: CGFloat = 32) {
        self.star = star
    }
}

public struct Motion: Sendable {
    public var quick: Double = 0.14
    public var standard: Double = 0.15
    public var progress: Double = 0.2

    public init() {}
}

public struct FormhausTheme: Sendable {
    public var light: Palette
    public var dark: Palette
    public var lightIncreased: Palette?
    public var darkIncreased: Palette?
    public var typography: Typography
    public var spacing: Spacing
    public var radii: Radii
    public var controls: Controls
    public var motion: Motion

    public init(
        light: Palette = .light, dark: Palette = .dark, typography: Typography, spacing: Spacing = Spacing(), radii: Radii = Radii(),
        controls: Controls, motion: Motion = Motion(), lightIncreased: Palette? = nil, darkIncreased: Palette? = nil
    ) {
        self.light = light
        self.dark = dark
        self.lightIncreased = lightIncreased
        self.darkIncreased = darkIncreased
        self.typography = typography
        self.spacing = spacing
        self.radii = radii
        self.controls = controls
        self.motion = motion
    }

    public static let pointer = FormhausTheme(typography: Typography(body: 15, small: 13), controls: Controls(star: 32))

    public static let touch: FormhausTheme = {
        var spacing = Spacing()
        spacing.cardPadding = 16
        return FormhausTheme(typography: Typography(body: 17, small: 15), spacing: spacing, controls: Controls(star: 40))
    }()

    #if os(iOS)
        public static let standard = touch
    #else
        public static let standard = pointer
    #endif
}
