import SwiftUI

public struct FormhausTokens: Sendable {
    public let colors: ResolvedPalette
    public let typography: Typography
    public let spacing: Spacing
    public let radii: Radii
    public let controls: Controls
    public let motion: Motion
    public let reduceMotion: Bool
    public let scale: CGFloat

    init(theme: FormhausTheme, dark: Bool, typeSize: DynamicTypeSize, reduceMotion: Bool) {
        let scale = typeScale(typeSize)
        let grow = max(1, scale)
        let rhythm = 1 + (grow - 1) / 2
        colors = ResolvedPalette(dark ? theme.dark : theme.light, dark: dark)
        var typography = theme.typography
        typography.body *= scale
        typography.small *= scale
        typography.heading *= scale
        typography.title *= scale
        self.typography = typography
        spacing = theme.spacing.scaled(rhythm)
        radii = theme.radii
        controls = theme.controls.scaled(grow)
        motion = theme.motion
        self.reduceMotion = reduceMotion
        self.scale = scale
    }

    public func animation(_ duration: Double) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: duration)
    }

    public var quick: Animation? { animation(motion.quick) }
}

extension Spacing {
    fileprivate func scaled(_ factor: CGFloat) -> Spacing {
        var copy = self
        copy.s1 *= factor
        copy.s2 *= factor
        copy.s3 *= factor
        copy.s4 *= factor
        copy.s5 *= factor
        copy.s6 *= factor
        copy.s7 *= factor
        copy.s8 *= factor
        copy.s9 *= factor
        copy.s10 *= factor
        copy.gap *= factor
        copy.cardPadding *= factor
        return copy
    }
}

extension Controls {
    fileprivate func scaled(_ factor: CGFloat) -> Controls {
        var copy = self
        copy.height *= factor
        copy.star *= factor
        copy.indicator *= factor
        copy.textareaHeight *= factor
        copy.matrixWidth *= factor
        copy.optionImageWidth *= factor
        return copy
    }
}

private func typeScale(_ size: DynamicTypeSize) -> CGFloat {
    let points: [DynamicTypeSize: CGFloat] = [
        .xSmall: 14, .small: 15, .medium: 16, .large: 17, .xLarge: 19, .xxLarge: 21, .xxxLarge: 23,
        .accessibility1: 28, .accessibility2: 33, .accessibility3: 40, .accessibility4: 47, .accessibility5: 53,
    ]
    return (points[size] ?? 17) / 17
}

extension EnvironmentValues {
    @Entry public var formhausTheme = FormhausTheme.standard
    @Entry public var formhausTokens = FormhausTokens(theme: .standard, dark: false, typeSize: .large, reduceMotion: false)
}

extension View {
    public func formhausTheme(_ theme: FormhausTheme) -> some View {
        environment(\.formhausTheme, theme)
    }

    func resolveFormhausTokens() -> some View {
        modifier(TokenResolver())
    }
}

private struct TokenResolver: ViewModifier {
    @Environment(\.formhausTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let tokens = FormhausTokens(theme: theme, dark: colorScheme == .dark, typeSize: typeSize, reduceMotion: reduceMotion)
        content.environment(\.formhausTokens, tokens).tint(tokens.colors.primary)
    }
}
