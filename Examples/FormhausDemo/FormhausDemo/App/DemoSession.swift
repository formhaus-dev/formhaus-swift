import FormhausCore
import FormhausUI
import Observation
import SwiftUI

struct Receipt: Equatable {
    let name: String
    let email: String
    let project: String
}

struct ScrollTarget: Equatable {
    let key: String
    let id: Int
}

@MainActor
@Observable
final class DemoSession {
    enum Phase: Equatable {
        case form
        case done(Receipt)
    }

    private(set) var language: DemoLanguage
    var style: DemoStyle
    private(set) var model: FormModel
    private(set) var phase = Phase.form
    private(set) var scrollTarget: ScrollTarget?
    @ObservationIgnored let timings: ScriptTimings
    @ObservationIgnored let launch: LaunchOptions
    @ObservationIgnored private let source: FormSource
    @ObservationIgnored private var registered: Set<String> = ["ada@lovelace.dev"]
    @ObservationIgnored private let relay: Relay

    init(launch: LaunchOptions, bundle: Bundle = .main) {
        self.launch = launch
        language = launch.language
        style = launch.style
        timings = ScriptTimings.load(from: bundle, speed: launch.speed)
        do {
            source = try FormSource(bundle: bundle)
        } catch {
            fatalError("The demo form could not be loaded: \(error)")
        }
        let relay = Relay()
        self.relay = relay
        model = Self.makeModel(source, launch.language, relay: relay)
        relay.session = self
    }

    var copy: DemoCopy { language.copy }

    var title: String { model.definition.title ?? "" }

    var definitionDescription: String? { model.definition.description }

    func setLanguage(_ next: DemoLanguage) {
        guard next != language, !model.submitting else { return }
        let values = model.engine.values
        let stepField = model.engine.currentStep?.fields.compactMap(\.field).first?.key
        language = next
        model = Self.makeModel(source, next, values: values, relay: relay)
        model.start()
        if let stepField { model.engine.goToStepWithField(stepField) }
    }

    func restart() {
        model.engine.cancelPendingActions()
        model = Self.makeModel(source, language, relay: relay)
        phase = .form
        scrollTarget = nil
    }

    func reveal(_ key: String) {
        scrollTarget = ScrollTarget(key: key, id: (scrollTarget?.id ?? 0) + 1)
    }

    private static func makeModel(
        _ source: FormSource, _ language: DemoLanguage, values: JSONObject = JSONObject(), relay: Relay
    ) -> FormModel {
        let localized: Localized
        do {
            localized = try source.localized(language)
        } catch {
            fatalError("The \(language.name) overlay could not be applied: \(error)")
        }
        var options = FormEngineOptions()
        options.onAfterSubmit = { values, _ in relay.session?.finish(values) }
        return FormModel(localized: localized, initialValues: values, engineOptions: options) { values, _ in
            try await relay.session?.send(values)
        }
    }

    private func send(_ values: JSONObject) async throws -> SubmitResult {
        try await Task.sleep(for: .seconds(timings.submitDelay))
        let email = values["email"]?.stringValue?.lowercased() ?? ""
        guard !registered.contains(email) else { return .rejected(errors: ["email": copy.emailTaken]) }
        registered.insert(email)
        return .ok
    }

    private func finish(_ values: JSONObject) {
        let project = values["projectType"]?.stringValue ?? ""
        let receipt = Receipt(
            name: values["name"]?.stringValue ?? "", email: values["email"]?.stringValue ?? "",
            project: optionLabel("projectType", project) ?? project)
        withAnimation(.snappy) { phase = .done(receipt) }
    }

    private func optionLabel(_ key: String, _ value: String) -> String? {
        let fields = (model.definition.steps ?? []).flatMap(\.fields).compactMap(\.field)
        return fields.first { $0.key == key }?.options?.first { $0.value == value }?.label
    }
}

@MainActor
private final class Relay {
    weak var session: DemoSession?
}
