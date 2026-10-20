@_spi(Renderer) import FormhausCore
import SwiftUI

struct SystemErrorSummary: View {
    @Environment(\.formhausBehavior) private var behavior
    @Environment(\.formhausTokens) private var tokens
    let model: FormModel

    var body: some View {
        let groups = model.errorGroups
        if behavior.errorSummary, let first = groups.first?.entries.first?.key {
            Section {
                ForEach(groups) { group in
                    ForEach(group.entries) { entry in
                        row(entry, step: groups.count > 1 ? group.title : nil)
                            .id(entry.key == first ? ScrollAnchor.summary(model) : "formhaus.summary.\(entry.key)")
                    }
                }
            } header: {
                Text(verbatim: model.text(forLabel: "errorSummary"))
                    .accessibilityAddTraits(.isHeader)
                    .formhausSummaryFocus(model)
            }
        }
    }

    private func row(_ entry: ErrorEntry, step: String?) -> some View {
        Button {
            model.focus(field: entry.key)
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: entry.text).foregroundStyle(tokens.colors.error)
                    if let step { Text(verbatim: step).font(.footnote).systemSecondaryText() }
                }
                .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.circle.fill").foregroundStyle(tokens.colors.error).accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
