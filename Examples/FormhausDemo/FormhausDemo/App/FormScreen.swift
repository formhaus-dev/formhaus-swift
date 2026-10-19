import FormhausUI
import SwiftUI

struct FormScreen: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let session: DemoSession

    var body: some View {
        ScrollViewReader { proxy in
            Group {
                if session.style == .system {
                    FormhausFormContent(model: session.model)
                } else {
                    scroller
                }
            }
            .id(ObjectIdentifier(session.model))
            .onChange(of: session.scrollTarget) { _, target in
                guard let target else { return }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.45)) { proxy.scrollTo(target.key, anchor: .center) }
            }
        }
        .formhausComponents(session.style.components)
        .formhausTheme(session.style.theme)
        .formhausBehavior(FormBehavior(errorSummary: true))
    }

    private var scroller: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    #if os(macOS)
                        Text(session.title)
                            .font(.largeTitle.weight(.bold))
                            .accessibilityAddTraits(.isHeader)
                    #endif
                    if let description = session.definitionDescription {
                        Text(description).font(session.style == .brand ? KilnType.body : .body).foregroundStyle(.secondary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                FormhausFormContent(model: session.model)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .hardTopEdge()
        .alignsBar(toColumn: 640, padding: 16)
        .background(session.style.background(scheme))
    }
}

extension View {
    @ViewBuilder
    fileprivate func hardTopEdge() -> some View {
        if #available(iOS 26, macOS 26, *) {
            scrollEdgeEffectStyle(.hard, for: .top)
        } else {
            self
        }
    }
}
