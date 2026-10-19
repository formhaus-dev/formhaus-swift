@_spi(Renderer) import FormhausCore
import SwiftUI

enum DateKind: Sendable {
    case date
    case time
    case datetime

    init(_ type: String) {
        switch type {
        case "time": self = .time
        case "datetime": self = .datetime
        default: self = .date
        }
    }

    var format: String {
        switch self {
        case .date: "yyyy-MM-dd"
        case .time: "HH:mm"
        case .datetime: "yyyy-MM-dd'T'HH:mm"
        }
    }

    var components: DatePickerComponents {
        switch self {
        case .date: .date
        case .time: .hourAndMinute
        case .datetime: [.date, .hourAndMinute]
        }
    }

    func pattern(_ locale: Locale) -> String {
        let date = DateFormatter.dateFormat(fromTemplate: "yyyyMMdd", options: 0, locale: locale)?.lowercased() ?? ""
        switch self {
        case .date: return date
        case .time: return "--:--"
        case .datetime: return "\(date), --:--"
        }
    }

    func formatter(_ timeZone: TimeZone = .current) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        return formatter
    }

    func date(_ text: String) -> Date? {
        let trimmed = self == .datetime ? String(text.prefix(16)) : self == .time ? String(text.prefix(5)) : text
        return formatter().date(from: trimmed)
    }

    func text(_ date: Date) -> String {
        formatter().string(from: date)
    }
}

public struct DateField: View {
    @Environment(\.formhausTokens) private var tokens
    @Environment(\.locale) private var locale
    @FocusState private var focused: Bool
    let context: FieldContext

    public init(_ context: FieldContext) {
        self.context = context
    }

    public var body: some View {
        FieldShell(context) {
            HStack(spacing: tokens.spacing.s3) {
                if let date {
                    DatePicker(selection: binding(date), displayedComponents: kind.components) { Text(context.label) }
                        .labelsHidden()
                        .datePickerStyle(.compact)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    LoadingIndicator(visible: context.loading)
                    if !context.isRequired, !context.isLocked {
                        IconButton(systemName: "xmark.circle.fill", label: context.label("removeItem"), embedded: true) {
                            context.setValue(.string(""))
                        }
                    }
                } else {
                    Button {
                        context.setValue(.string(kind.text(Date())))
                    } label: {
                        HStack {
                            Text(context.field.placeholder ?? pattern)
                                .formhausText(.body, colored: false)
                                .foregroundStyle(tokens.colors.control)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            LoadingIndicator(visible: context.loading)
                            Image(systemName: kind == .time ? "clock" : "calendar").foregroundStyle(tokens.colors.textMuted)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(context.label)
                }
            }
            .padding(.horizontal, date == nil ? 0 : tokens.spacing.s4)
            .inputChrome(focused: focused, invalid: context.isInvalid, disabled: context.isLocked, padded: date == nil)
            .disabled(context.isLocked)
            .fieldFocus(context, $focused)
            .accessibilityHint(context.helperText ?? "")
        }
    }

    private var kind: DateKind { DateKind(context.field.type) }

    private var date: Date? {
        context.text.isEmpty ? nil : kind.date(context.text)
    }

    private var pattern: String { kind.pattern(locale) }

    private func binding(_ current: Date) -> Binding<Date> {
        Binding(get: { current }, set: { context.setValue(.string(kind.text($0))) })
    }
}
