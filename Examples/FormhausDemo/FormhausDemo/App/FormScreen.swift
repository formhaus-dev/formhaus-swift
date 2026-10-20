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
        .formhausComponents(components)
        .formhausTheme(session.style.theme)
        .formhausBehavior(FormBehavior())
    }

    private var components: FormComponents {
        let tracked = session.style == .formhaus && session.launch.script != nil
        return tracked ? session.style.components.tracking(session.frames) : session.style.components
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
        .topBar(session.style.palette(scheme, contrast).background)
        .alignsBar(toColumn: 640, padding: 16)
        .background(session.style.palette(scheme, contrast).background)
    }
}

extension View {
    @ViewBuilder
    fileprivate func topBar(_ background: Color) -> some View {
        #if os(iOS)
            toolbarBackground(background, for: .navigationBar)
        #else
            if #available(macOS 26, *) { scrollEdgeEffectStyle(.hard, for: .top) } else { self }
        #endif
    }
}
