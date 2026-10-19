import SwiftUI

public enum TextRole: Sendable {
    case body
    case label
    case option
    case helper
    case error
    case heading
    case title
    case counter
    case itemTitle
    case caption
    case button
    case textButton
    case smallButton

    var leading: CGFloat {
        switch self {
        case .body, .option: 1.5
        case .label, .itemTitle: 1.4
        case .helper, .error, .counter: 1.45
        case .heading: 1.35
        case .title, .caption: 1.3
        case .button, .textButton, .smallButton: 1.2
        }
    }

    var weight: Font.Weight {
        switch self {
        case .label, .heading, .title, .itemTitle, .button: .semibold
        case .error, .textButton, .smallButton, .caption: .medium
        default: .regular
        }
    }

    var isSmall: Bool {
        [.helper, .error, .counter, .itemTitle, .caption, .smallButton].contains(self)
    }

    func size(_ typography: Typography) -> CGFloat {
        switch self {
        case .heading: typography.heading
        case .title: typography.title
        default: isSmall ? typography.small : typography.body
        }
    }

    func color(_ colors: ResolvedPalette) -> Color {
        switch self {
        case .helper, .counter, .itemTitle, .caption, .textButton: colors.textMuted
        case .error: colors.error
        default: colors.text
        }
    }
}

extension FormhausTokens {
    public func font(_ role: TextRole) -> Font {
        let font = Font.system(size: role.size(typography), weight: role.weight, design: typography.design)
        return role == .counter || role == .itemTitle ? font.monospacedDigit() : font
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
