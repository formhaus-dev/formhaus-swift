import FormhausCore
import FormhausUI

@MainActor
protocol ScriptStage: AnyObject {
    var model: FormModel { get }
    func reveal(_ key: String)
    func setLanguage(_ language: DemoLanguage)
}

@MainActor
struct ScriptRunner {
    let script: DemoScript
    let timings: ScriptTimings
    let stopAt: String?
    let stage: any ScriptStage

    func run() async {
        for beat in script.beats {
            if Task.isCancelled { return }
            if case .mark(let name) = beat, name == stopAt { return }
            await play(beat)
        }
    }

    private func play(_ beat: Beat) async {
        let model = stage.model
        switch beat {
        case .wait(let pace): await pause(timings.duration(pace))
        case .mark: break
        case .reveal(let key): stage.reveal(key)
        case .type(let key, let text): await type(text, into: key)
        case .clear(let key): model.setValue(.null, forKey: key)
        case .pick(let key, let value): model.commitValue(value, forKey: key)
        case .toggle(let key, let option): toggle(option, in: key)
        case .next: await model.next()
        case .back: await model.back()
        case .submit: await model.submit()
        case .language(let language): stage.setLanguage(language)
        }
    }

    private func type(_ text: String, into key: String) async {
        var typed = ""
        for character in text {
            if Task.isCancelled { return }
            typed.append(character)
            stage.model.setValue(.string(typed), forKey: key)
            await pause(timings.keystroke(after: character))
        }
    }

    private func toggle(_ option: String, in key: String) {
        var selected = stage.model.field(key).value?.arrayValue ?? []
        if let index = selected.firstIndex(of: .string(option)) {
            selected.remove(at: index)
        } else {
            selected.append(.string(option))
        }
        stage.model.commitValue(.array(selected), forKey: key)
    }

    private func pause(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }
}
