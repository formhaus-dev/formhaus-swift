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
    @State private var picking = false
    let context: FieldContext

    public init(_ context: FieldContext) {
        self.context = context
    }

    public var body: some View {
        FieldShell(context) {
            HStack(spacing: tokens.spacing.s3) {
                Button {
                    picking = true
                } label: {
                    HStack(spacing: tokens.spacing.s3) {
                        Text(display ?? context.field.placeholder ?? kind.pattern(locale))
                            .formhausText(.body, colored: false)
                            .foregroundStyle(
                                display == nil ? tokens.colors.control : context.isLocked ? tokens.colors.textMuted : tokens.colors.text
                            )
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: kind == .time ? "clock" : "calendar").foregroundStyle(tokens.colors.textMuted)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(context.accessibilityName)
                .accessibilityValue(display ?? "")
                .datePickerPresentation(isPresented: $picking) {
                    DatePickerPanel(kind: kind, initial: date ?? Date(), label: context.label) { picked in
                        context.setValue(.string(kind.text(picked)))
                        if kind == .date { picking = false }
                    }
                }
                FieldAccessories(context: context, clearable: date != nil) { context.setValue(.string("")) }
            }
            .inputChrome(focused: focused || picking, invalid: context.isInvalid, disabled: context.isLocked)
            .disabled(context.isLocked)
            .formhausFocus(context, $focused)
            .accessibilityHint(context.helperText ?? "")
        }
    }

    private var kind: DateKind { DateKind(context.field.type) }

    private var date: Date? {
        context.text.isEmpty ? nil : kind.date(context.text)
    }

    private var display: String? {
        guard let date else { return nil }
        switch kind {
        case .date: return date.formatted(Date.FormatStyle(date: .long, time: .omitted, locale: locale))
        case .time: return date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: locale))
        case .datetime: return date.formatted(Date.FormatStyle(date: .long, time: .shortened, locale: locale))
        }
    }
}

private struct DatePickerPanel: View {
    @Environment(\.formhausTokens) private var tokens
    @State private var draft: Date
    let kind: DateKind
    let label: String
    let pick: (Date) -> Void

    init(kind: DateKind, initial: Date, label: String, pick: @escaping (Date) -> Void) {
        self.kind = kind
        self.label = label
        self.pick = pick
        _draft = State(initialValue: initial)
    }

    var body: some View {
        DatePicker(selection: selection, displayedComponents: kind.components) { Text(label) }
            .labelsHidden()
            .modifier(PickerStyleChoice(kind: kind))
            .tint(tokens.colors.primary)
            .padding(tokens.spacing.s7)
    }

    private var selection: Binding<Date> {
        Binding(
            get: { draft },
            set: {
                draft = $0
                pick($0)
            })
    }
}

private struct PickerStyleChoice: ViewModifier {
    let kind: DateKind

    func body(content: Content) -> some View {
        #if os(iOS)
            if kind == .time {
                content.datePickerStyle(.wheel)
            } else {
                content.datePickerStyle(.graphical)
            }
        #else
            if kind == .time {
                content.datePickerStyle(.stepperField)
            } else {
                content.datePickerStyle(.graphical)
            }
        #endif
    }
}

extension View {
    fileprivate func datePickerPresentation(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> some View) -> some View {
        #if os(iOS)
            sheet(isPresented: isPresented) { content().presentationDetents([.medium, .large]) }
        #else
            popover(isPresented: isPresented, arrowEdge: .bottom, content: content)
        #endif
    }
}
