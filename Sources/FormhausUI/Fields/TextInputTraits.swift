@_spi(Renderer) import FormhausCore
import SwiftUI

enum InputKind: Equatable {
    case text
    case email
    case phone
    case number
    case decimal
    case url
    case search
    case password

    init(_ field: FormField) {
        switch field.type {
        case "email": self = .email
        case "phone": self = .phone
        case "password": self = .password
        case "number": self = field.inputMode?.stringValue == "numeric" ? .number : .decimal
        default: self = InputKind(mode: field.inputMode?.stringValue)
        }
    }

    private init(mode: String?) {
        switch mode {
        case "email": self = .email
        case "tel": self = .phone
        case "numeric": self = .number
        case "decimal": self = .decimal
        case "url": self = .url
        case "search": self = .search
        default: self = .text
        }
    }

    var isLiteral: Bool { [.email, .url, .password, .phone].contains(self) }
}

struct TextInputTraits: ViewModifier {
    let kind: InputKind

    func body(content: Content) -> some View {
        #if os(iOS)
            content
                .keyboardType(keyboard)
                .textContentType(contentType)
                .textInputAutocapitalization(kind.isLiteral ? .never : .sentences)
                .autocorrectionDisabled(disablesCorrection)
        #else
            content.autocorrectionDisabled(disablesCorrection)
        #endif
    }

    private var disablesCorrection: Bool {
        kind.isLiteral || kind == .number || kind == .decimal
    }

    #if os(iOS)
        private var keyboard: UIKeyboardType {
            switch kind {
            case .email: .emailAddress
            case .phone: .phonePad
            case .number: .numberPad
            case .decimal: .decimalPad
            case .url: .URL
            case .search: .webSearch
            case .text, .password: .default
            }
        }

        private var contentType: UITextContentType? {
            switch kind {
            case .email: .emailAddress
            case .phone: .telephoneNumber
            case .url: .URL
            case .password: .password
            default: nil
            }
        }
    #endif
}

extension View {
    func textInputTraits(_ kind: InputKind) -> some View {
        modifier(TextInputTraits(kind: kind))
    }
}
