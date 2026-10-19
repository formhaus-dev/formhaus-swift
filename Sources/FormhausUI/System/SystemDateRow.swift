import SwiftUI

struct SystemDateRow: View {
    @Environment(\.locale) private var locale
    @FocusState private var focused: Bool
    @State private var expanded = false
    let context: FieldContext

    var body: some View {
        SystemRow(context: context) {
            Button {
                expanded.toggle()
            } label: {
                HStack {
                    Text(context.label).foregroundStyle(Color.primary)
                    Spacer(minLength: 12)
                    if let display {
                        Text(display)
                            .foregroundStyle(expanded ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        Text(context.prompt).foregroundStyle(expanded ? AnyShapeStyle(.tint) : AnyShapeStyle(systemSecondary))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(context.accessibilityName)
            .accessibilityValue(display ?? "")
            .accessibilityHint(context.helperText ?? "")
            .formhausFocus(context, $focused)
            #if os(macOS)
                .popover(isPresented: $expanded, arrowEdge: .bottom) { panel.padding(16).frame(minWidth: 280) }
            #endif
        }
        #if os(iOS)
            if expanded { panel.disabled(context.isLocked) }
        #endif
    }

    private var panel: some View {
        SystemDatePanel(
            kind: kind, initial: date ?? Date(), label: context.label,
            clear: !context.isRequired && date != nil ? context.text(forLabel: "clear") : nil, done: context.text(forLabel: "done")
        ) { date in
            if let date { context.setValue(.string(kind.text(date))) } else { context.setValue(.string("")) }
            expanded = false
        }
    }

    private var kind: DateKind { DateKind(context.field.type) }

    private var date: Date? {
        context.text.isEmpty ? nil : kind.date(context.text)
    }

    private var display: String? {
        kind.display(context.text, dateStyle: .abbreviated, locale: locale)
    }
}

private struct SystemDatePanel: View {
    @State private var draft: Date
    let kind: DateKind
    let label: String
    let clear: String?
    let done: String
    let commit: (Date?) -> Void

    init(kind: DateKind, initial: Date, label: String, clear: String?, done: String, commit: @escaping (Date?) -> Void) {
        self.kind = kind
        self.label = label
        self.clear = clear
        self.done = done
        self.commit = commit
        _draft = State(initialValue: initial)
    }

    var body: some View {
        VStack(spacing: 8) {
            DatePicker(selection: selection, displayedComponents: kind.components) { Text(label) }
                .labelsHidden()
                .modifier(DatePickerStyleChoice(kind: kind))
            if clear != nil || kind != .date {
                HStack {
                    if let clear { DateAction(title: clear, role: .destructive) { commit(nil) } }
                    Spacer()
                    if kind != .date { DateAction(title: done, role: nil) { commit(draft) }.keyboardShortcut(.defaultAction) }
                }
            }
        }
    }

    private var selection: Binding<Date> {
        Binding(
            get: { draft },
            set: {
                draft = $0
                if kind == .date { commit($0) }
            })
    }
}

private struct DateAction: View {
    let title: String
    let role: ButtonRole?
    let action: () -> Void

    var body: some View {
        Button(title, role: role, action: action)
            .buttonStyle(.borderless)
            .fontWeight(role == nil ? .semibold : .regular)
            .frame(minHeight: 44)
    }
}
