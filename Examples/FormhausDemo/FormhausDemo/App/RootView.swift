import FormhausUI
import SwiftUI

extension DemoSession: ScriptStage {}

struct RootView: View {
    @Environment(\.colorScheme) private var scheme
    let session: DemoSession

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(session.phase == .form ? session.title : "")
                #if os(iOS)
                    .navigationBarTitleDisplayMode(.large)
                #endif
                .toolbar { toolbar }
        }
        .id(session.style)
        .tint(session.style.tint(scheme))
        .task { await playScript() }
    }

    @ViewBuilder private var content: some View {
        switch session.phase {
        case .form:
            FormScreen(session: session).transition(.opacity)
        case .done(let receipt):
            SuccessView(receipt: receipt, copy: session.copy) { session.restart() }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        #if os(macOS)
            ToolbarItem(placement: .principal) {
                Picker(session.copy.style, selection: styleBinding) {
                    ForEach(DemoStyle.allCases) { style in Text(style.name).tag(style) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
        #endif
        ToolbarItem(placement: .primaryAction) {
            Menu {
                #if os(iOS)
                    Picker(selection: styleBinding) {
                        ForEach(DemoStyle.allCases) { style in Label(style.name, systemImage: style.symbol).tag(style) }
                    } label: {
                        Label(session.copy.style, systemImage: "swatchpalette")
                    }
                    .pickerStyle(.menu)
                #endif
                Picker(selection: Binding(get: { session.language }, set: { session.setLanguage($0) })) {
                    ForEach(DemoLanguage.allCases) { language in Text(language.name).tag(language) }
                } label: {
                    Label(session.copy.language, systemImage: "globe")
                }
                .pickerStyle(.menu)
                Divider()
                Button {
                    session.restart()
                } label: {
                    Label(session.copy.restart, systemImage: "arrow.counterclockwise")
                }
            } label: {
                Label(session.copy.options, systemImage: "ellipsis")
            }
        }
    }

    private var styleBinding: Binding<DemoStyle> {
        Binding(get: { session.style }, set: { style in withAnimation(.snappy) { session.style = style } })
    }

    private func playScript() async {
        guard let name = session.launch.script, let script = DemoScript.named(name) else { return }
        ScriptKeyboard.hide()
        let runner = ScriptRunner(script: script, timings: session.timings, stopAt: session.launch.stopAt, stage: session)
        await runner.run()
    }
}

enum Brand {
    static func primary(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Palette.dark.primary : Palette.light.primary
    }

    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Palette.dark.background : Palette.light.background
    }
}
