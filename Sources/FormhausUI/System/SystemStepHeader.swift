@_spi(Renderer) import FormhausCore
import SwiftUI

struct SystemStepHeader: View {
    let model: FormModel
    let step: FormStep?
    let level: Int

    var body: some View {
        let texts = step.map { model.texts(for: $0) }
        let title = model.structure.isMultiStep ? stepTitle(texts?.title) : nil
        let description = texts?.description.flatMap { $0.isEmpty ? nil : $0 }
        if title != nil || description != nil {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    if let title {
                        Text(verbatim: title).font(.title3.weight(.semibold)).foregroundStyle(Color.primary)
                            .accessibilityAddTraits(.isHeader)
                    }
                    if let description { Text(verbatim: description).font(.body).systemSecondaryText() }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))
            }
        }
    }

    private func stepTitle(_ title: String?) -> String {
        if let title, !title.isEmpty { return title }
        return model.text(forLabel: "stepTitle", ["index": .number(Double(level + 1))])
    }
}
