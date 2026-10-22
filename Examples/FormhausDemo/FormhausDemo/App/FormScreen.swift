import FormhausUI
import SwiftUI

struct FormScreen: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    let session: DemoSession

    var body: some View {
        Group {
            if session.style == .system {
                FormhausFormContent(model: session.model)
            } else {
                scroller
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
                FormhausFormContent(model: session.model).id(ObjectIdentifier(session.model))
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .hardTopEdge(session.style.palette(scheme, contrast).background)
        .alignsBar(toColumn: 640, padding: 16)
        .background(session.style.palette(scheme, contrast).background)
    }
}

extension View {
    @ViewBuilder
    fileprivate func hardTopEdge(_ background: Color) -> some View {
        #if os(iOS)
            if #available(iOS 26, *) {
                toolbarBackground(background, for: .navigationBar)
                    .overlay {
                        GeometryReader { proxy in
                            let top = proxy.frame(in: .global).minY
                            background.frame(height: max(0, top)).offset(y: -top)
                        }
                        .ignoresSafeArea(edges: .horizontal)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                    }
            } else {
                toolbarBackground(background, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar)
            }
        #else
            if #available(macOS 26, *) { scrollEdgeEffectStyle(.hard, for: .top) } else { self }
        #endif
    }
}
