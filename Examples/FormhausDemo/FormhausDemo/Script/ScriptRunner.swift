import FormhausCore
import FormhausUI

@MainActor
protocol ScriptStage: AnyObject {
    var model: FormModel { get }
    func setLanguage(_ language: DemoLanguage)
    var style: DemoStyle { get set }
    var frames: FieldFrames { get }
}

@MainActor
struct ScriptRunner {
    let script: DemoScript
    let timings: ScriptTimings
    let stopAt: String?
    let stage: any ScriptStage

    func run() async {
        let timeline = ScriptTimeline()
        for beat in script.beats {
            if Task.isCancelled { return }
            if case .mark(let name) = beat, name == stopAt { return }
            record(beat, on: timeline)
            await play(beat)
        }
    }

    private func record(_ beat: Beat, on timeline: ScriptTimeline) {
        switch beat {
        case .mark(let name): timeline.mark(name)
        case .type(let key, _): field("type", key, on: timeline)
        case .pick(let key, _): field("pick", key, on: timeline)
        case .toggle(let key, _): field("toggle", key, on: timeline)
        case .next: timeline.tap("next")
        case .back: timeline.tap("back")
        case .submit: timeline.tap("submit")
        default: break
        }
    }

    private func field(_ kind: String, _ key: String, on timeline: ScriptTimeline) {
        let index = timeline.tap(kind, key: key, target: stage.frames.frames[key])
        let stage = stage
        Task {
            try? await Task.sleep(for: .seconds(0.4))
            timeline.settle(index, target: stage.frames.frames[key])
        }
    }

    private func play(_ beat: Beat) async {
        let model = stage.model
        switch beat {
        case .wait(let pace): await pause(timings.duration(pace))
        case .mark: break
        case .type(let key, let text): await type(text, into: key)
        case .clear(let key): model.setValue(.null, forKey: key)
        case .pick(let key, let value): model.commitValue(value, forKey: key)
        case .toggle(let key, let option): toggle(option, in: key)
        case .next: await model.next()
        case .back: await model.back()
        case .submit: await model.submit()
        case .language(let language): stage.setLanguage(language)
        case .style(let style): stage.style = style
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
