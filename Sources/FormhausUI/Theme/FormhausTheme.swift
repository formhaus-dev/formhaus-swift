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
        self.heading = heading ?? body + Typography.headingStep
        self.title = title ?? body + Typography.titleStep
        self.design = design
    }
}

public struct Spacing: Sendable {
    public var s1: CGFloat
    public var s2: CGFloat
    public var s3: CGFloat
    public var s4: CGFloat
    public var s5: CGFloat
    public var s6: CGFloat
    public var s7: CGFloat
    public var s8: CGFloat
    public var s9: CGFloat
    public var s10: CGFloat
    public var gap: CGFloat
    public var cardPadding: CGFloat
}

extension Spacing {
    public init() {
        self = .regular
    }
}

public struct Radii: Sendable {
    public var control: CGFloat
    public var indicator: CGFloat = NativeMetrics.indicatorRadius
}

extension Radii {
    public init() {
        self = .standard
    }
}

public struct Controls: Sendable {
    public var height: CGFloat
    public var iconButton: CGFloat
    public var star: CGFloat
    public var optionImageWidth: CGFloat
    public var hitTarget: CGFloat = NativeMetrics.hitTarget
    public var indicator: CGFloat = NativeMetrics.indicator
    public var textareaHeight: CGFloat = NativeMetrics.textareaHeight
    public var progressHeight: CGFloat = NativeMetrics.progressHeight
    public var maxWidth: CGFloat = NativeMetrics.maxWidth
    public var compactWidth: CGFloat = NativeMetrics.compactWidth
    public var matrixWidth: CGFloat = NativeMetrics.matrixWidth
}

extension Controls {
    public init(star: CGFloat? = nil) {
        self = .fine
        if let star { self.star = star }
    }
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

    public static let pointer = FormhausTheme(typography: .fine, spacing: .regular, controls: .fine)

    public static let touch = FormhausTheme(typography: .coarse, spacing: .compact, controls: .coarse)

    #if os(iOS)
        public static let standard = touch
    #else
        public static let standard = pointer
    #endif
}
