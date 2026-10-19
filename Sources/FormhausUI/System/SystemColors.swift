import SwiftUI

#if os(iOS)
    import UIKit

    private func dynamic(_ light: UInt32, _ dark: UInt32, _ lightHigh: UInt32, _ darkHigh: UInt32) -> Color {
        Color(
            UIColor { traits in
                let high = traits.accessibilityContrast == .high
                let hex = traits.userInterfaceStyle == .dark ? (high ? darkHigh : dark) : (high ? lightHigh : light)
                return UIColor(Color(hex: hex))
            })
    }
#else
    import AppKit

    private func dynamic(_ light: UInt32, _ dark: UInt32, _ lightHigh: UInt32, _ darkHigh: UInt32) -> Color {
        Color(
            NSColor(name: nil) { appearance in
                let match = appearance.bestMatch(from: [
                    .aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua,
                ])
                let hex: UInt32 =
                    switch match {
                    case .darkAqua?: dark
                    case .accessibilityHighContrastAqua?: lightHigh
                    case .accessibilityHighContrastDarkAqua?: darkHigh
                    default: light
                    }
                return NSColor(Color(hex: hex))
            })
    }
#endif

let systemSecondary = dynamic(0x6C6C70, 0xAEAEB2, 0x48484C, 0xD1D1D6)

extension View {
    func systemSecondaryText() -> some View {
        foregroundStyle(systemSecondary)
    }
}
