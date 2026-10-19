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

    func palette(_ scheme: ColorScheme, _ contrast: ColorSchemeContrast) -> Palette {
        theme.palette(for: scheme, contrast: contrast)
    }
}
