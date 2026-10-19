import SwiftUI

public struct TextRole: Sendable, Hashable {
    public enum Size: Sendable, Hashable {
        case body
        case small
        case heading
        case title
    }

    public enum Tone: Sendable, Hashable {
        case text
        case muted
        case error
    }

    public let size: Size
    public let weight: Font.Weight
    public let leading: CGFloat
    public let tone: Tone
    public let tabularDigits: Bool

    public init(size: Size, weight: Font.Weight = .regular, leading: CGFloat = 1.5, tone: Tone = .text, tabularDigits: Bool = false) {
        self.size = size
        self.weight = weight
        self.leading = leading
        self.tone = tone
        self.tabularDigits = tabularDigits
    }

    public static let body = TextRole(size: .body)
    public static let label = TextRole(size: .body, weight: .semibold, leading: 1.4)
    public static let option = TextRole(size: .body)
    public static let helper = TextRole(size: .small, leading: 1.45, tone: .muted)
    public static let error = TextRole(size: .small, weight: .medium, leading: 1.45, tone: .error)
    public static let heading = TextRole(size: .heading, weight: .semibold, leading: 1.35)
    public static let title = TextRole(size: .title, weight: .semibold, leading: 1.3)
    public static let counter = TextRole(size: .small, leading: 1.45, tone: .muted, tabularDigits: true)
    public static let itemTitle = TextRole(size: .small, weight: .semibold, leading: 1.4, tone: .muted, tabularDigits: true)
    public static let caption = TextRole(size: .small, weight: .medium, leading: 1.3, tone: .muted)
    public static let button = TextRole(size: .body, weight: .semibold, leading: 1.2)
    public static let textButton = TextRole(size: .body, weight: .medium, leading: 1.2, tone: .muted)

    func size(_ typography: Typography) -> CGFloat {
        switch size {
        case .body: typography.body
        case .small: typography.small
        case .heading: typography.heading
        case .title: typography.title
        }
    }

    func color(_ colors: ResolvedPalette) -> Color {
        switch tone {
        case .text: colors.text
        case .muted: colors.textMuted
        case .error: colors.error
        }
    }
}

extension FormhausTokens {
    public func font(_ role: TextRole) -> Font {
        let font = Font.system(size: role.size(typography), weight: role.weight, design: typography.design)
        return role.tabularDigits ? font.monospacedDigit() : font
    }

    public func lineSpacing(_ role: TextRole) -> CGFloat {
        max(0, role.size(typography) / max(1, scale) * (role.leading - 1.2))
    }
}

private struct TextStyle: ViewModifier {
    @Environment(\.formhausTokens) private var tokens
    let role: TextRole
    let colored: Bool

    func body(content: Content) -> some View {
        let styled = content.font(tokens.font(role)).lineSpacing(tokens.lineSpacing(role))
        if colored {
            styled.foregroundStyle(role.color(tokens.colors))
        } else {
            styled
        }
    }
}

extension View {
    public func formhausText(_ role: TextRole, colored: Bool = true) -> some View {
        modifier(TextStyle(role: role, colored: colored))
    }
}
