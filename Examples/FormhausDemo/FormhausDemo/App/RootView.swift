import FormhausUI
import SwiftUI

extension DemoSession: ScriptStage {}

struct RootView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    let session: DemoSession

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(session.titled ? session.title : "")
                #if os(iOS)
                    .navigationBarTitleDisplayMode(.large)
                #endif
                .toolbar { toolbar }
        }
        .tint(session.style.palette(scheme, contrast).primary)
        .task { await playScript() }
    }

    @ViewBuilder private var content: some View {
        switch session.phase {
        case .form:
            FormScreen(session: session).transition(.opacity)
        case .done(let receipt):
            SuccessView(receipt: receipt, copy: session.copy) { session.restart() }
                .transition(.opacity)
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
        if session.launch.warmup { await warmUp(script) }
        if session.launch.ticker { FrameTicker.install() }
        let runner = ScriptRunner(script: script, timings: session.timings, stopAt: session.launch.stopAt, stage: session)
        await runner.run()
    }

    private func warmUp(_ script: DemoScript) async {
        await ScriptRunner(script: script, timings: session.timings.faster(6), stopAt: session.launch.stopAt, stage: session).run()
        try? await Task.sleep(for: .seconds(0.8))
        session.restart()
        try? await Task.sleep(for: .seconds(0.8))
    }
}

enum Brand {
    static func palette(_ scheme: ColorScheme, _ contrast: ColorSchemeContrast) -> Palette {
        FormhausTheme.standard.palette(for: scheme, contrast: contrast)
    }
}
