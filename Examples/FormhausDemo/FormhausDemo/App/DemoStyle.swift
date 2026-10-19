import FormhausUI
import SwiftUI

enum DemoStyle: String, CaseIterable, Identifiable, Sendable {
    case formhaus
    case system
    case brand

    var id: String { rawValue }

    var name: String {
        switch self {
        case .formhaus: "formhaus"
        case .system:
            #if os(macOS)
                "macOS"
            #else
                "iOS"
            #endif
        case .brand: "Kiln"
        }
    }

    var symbol: String {
        switch self {
        case .formhaus: "square.stack.3d.up"
        case .system: "gearshape"
        case .brand: "paintpalette"
        }
    }

    var components: FormComponents {
        switch self {
        case .formhaus: .standard
        case .system: .system
        case .brand: .kiln
        }
    }

    var theme: FormhausTheme {
        self == .brand ? .kiln : .standard
    }

    func background(_ scheme: ColorScheme) -> Color {
        let palette = scheme == .dark ? theme.dark : theme.light
        return palette.background
    }

    func tint(_ scheme: ColorScheme) -> Color {
        let palette = scheme == .dark ? theme.dark : theme.light
        return palette.primary
    }
}
