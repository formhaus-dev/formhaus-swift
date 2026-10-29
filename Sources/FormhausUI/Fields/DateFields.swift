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

    func display(_ text: String, dateStyle: Date.FormatStyle.DateStyle, locale: Locale) -> String? {
        guard !text.isEmpty, let date = date(text) else { return nil }
        let style: Date.FormatStyle.DateStyle = self == .time ? .omitted : dateStyle
        return date.formatted(Date.FormatStyle(date: style, time: self == .date ? .omitted : .shortened, locale: locale))
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
    @State private var picking = false
    let context: FieldContext

    public init(_ context: FieldContext) {
        self.context = context
    }

    public var body: some View {
        PickerInput(context: context, active: picking, clearable: date != nil, cleared: .string(""), label: summary) { picking = true }
            .datePickerPresentation(isPresented: $picking) {
                DatePickerPanel(kind: kind, initial: date ?? Date(), label: context.label, done: context.text(forLabel: "done")) {
                    context.setValue(.string(kind.text($0)))
                    picking = false
                }
            }
    }

    private var summary: some View {
        HStack(spacing: tokens.spacing.s3) {
            Text(verbatim: display ?? context.placeholder ?? kind.pattern(locale))
                .formhausText(.body, colored: false)
                .foregroundStyle(
                    display == nil ? tokens.colors.control : context.isLocked ? tokens.colors.textMuted : tokens.colors.text
                )
                .accessibleLineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if display == nil {
                Image(systemName: kind == .time ? "clock" : "calendar").foregroundStyle(tokens.colors.textMuted)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: context.accessibilityName))
        .accessibilityValue(display ?? "")
        .accessibilityAddTraits(.isButton)
    }

    private var kind: DateKind { DateKind(context.field.type) }

    private var date: Date? {
        context.text.isEmpty ? nil : kind.date(context.text)
    }

    private var display: String? {
        kind.display(context.text, dateStyle: .long, locale: locale)
    }
}

private struct DatePickerPanel: View {
    @Environment(\.formhausTokens) private var tokens
    @State private var draft: Date
    let kind: DateKind
    let label: String
    let done: String
    let pick: (Date) -> Void

    init(kind: DateKind, initial: Date, label: String, done: String, pick: @escaping (Date) -> Void) {
        self.kind = kind
        self.label = label
        self.done = done
        self.pick = pick
        _draft = State(initialValue: initial)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: tokens.spacing.s5) {
            DatePicker(selection: selection, displayedComponents: kind.components) { Text(verbatim: label) }
                .labelsHidden()
                .modifier(DatePickerStyleChoice(kind: kind))
                .tint(tokens.colors.primary)
            Button(done) { pick(draft) }
                .buttonStyle(FormButtonStyle(.primary, compact: true))
                .keyboardShortcut(.defaultAction)
        }
        .padding(tokens.spacing.s7)
    }

    private var selection: Binding<Date> {
        Binding(
            get: { draft },
            set: {
                draft = $0
                if kind == .date { pick($0) }
            })
    }
}

struct DatePickerStyleChoice: ViewModifier {
    let kind: DateKind

    func body(content: Content) -> some View {
        #if os(iOS)
            if kind == .time { content.datePickerStyle(.wheel) } else { content.datePickerStyle(.graphical) }
        #else
            if kind == .time { content.datePickerStyle(.stepperField) } else { content.datePickerStyle(.graphical) }
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
