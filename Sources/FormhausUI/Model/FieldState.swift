@_spi(Renderer) import FormhausCore
import Observation

@MainActor
@Observable
public final class FieldState {
    public let key: String
    public private(set) var value: JSONValue?
    public private(set) var error: String?
    public private(set) var loading = false
    public private(set) var version = 0
    public private(set) var focusToken = 0
    @ObservationIgnored private var focusPending: Int?

    init(key: String) {
        self.key = key
    }

    func requestFocus(_ id: Int) {
        focusPending = id
        focusToken += 1
    }

    func dropFocusRequest() {
        focusPending = nil
    }

    func takeFocusRequest() -> Int? {
        defer { focusPending = nil }
        return focusPending
    }

    func update(value: JSONValue?, error: String?, loading: Bool) {
        var changed = false
        if self.value != value {
            self.value = value
            changed = true
        }
        if self.error != error {
            self.error = error
            changed = true
        }
        if self.loading != loading {
            self.loading = loading
            changed = true
        }
        if changed { version += 1 }
    }
}

@MainActor
@Observable
public final class GroupState {
    public let key: String
    public private(set) var items: [GroupItem] = []
    public private(set) var hasContent: [Bool] = []

    init(key: String) {
        self.key = key
    }

    func update(_ items: [GroupItem], hasContent: [Bool]) {
        if self.items != items { self.items = items }
        if self.hasContent != hasContent { self.hasContent = hasContent }
    }
}

@MainActor
@Observable
final class OptionsState {
    private(set) var options: [FieldOption]?
    @ObservationIgnored var request = 0
    @ObservationIgnored var source: OptionsSource?

    func update(_ options: [FieldOption]?) {
        if self.options != options { self.options = options }
    }

    func cancel() {
        request += 1
        source = nil
        update(nil)
    }
}

struct OptionsSource: Equatable {
    let provider: String
    let revision: Int
    let inputs: [JSONValue?]

    static func == (lhs: OptionsSource, rhs: OptionsSource) -> Bool {
        lhs.provider == rhs.provider && lhs.revision == rhs.revision && lhs.inputs == rhs.inputs
    }
}

public struct FormStructure: Equatable {
    public let nodes: [FormNode]
    public let steps: [FormStep]
    public let currentStep: FormStep?
    public let stepIndex: Int
    public let progress: StepProgress
    public let isMultiStep: Bool
    public let isFirstStep: Bool
    public let isLastStep: Bool
    let revision: Int
    let signature: [Int]

    @MainActor
    init(_ engine: FormEngine) {
        nodes = engine.visibleNodes
        steps = engine.visibleSteps
        currentStep = engine.currentStep
        stepIndex = engine.currentStepIndex
        progress = engine.progress
        isMultiStep = engine.isMultiStep
        isFirstStep = engine.isFirstStep
        isLastStep = engine.isLastStep
        revision = engine.definitionRevision
        signature = nodeSignature(nodes) + [-2] + steps.map(\.nodeID)
    }

    public var visibleFields: [FormField] {
        nodes.flatMap { node -> [FormField] in
            switch node {
            case .field(let field): [field]
            case .section(let section): section.fields.compactMap(\.field)
            }
        }
    }

    public static func == (lhs: FormStructure, rhs: FormStructure) -> Bool {
        lhs.revision == rhs.revision && lhs.signature == rhs.signature && lhs.stepIndex == rhs.stepIndex && lhs.progress == rhs.progress
            && lhs.currentStep?.nodeID == rhs.currentStep?.nodeID && lhs.isLastStep == rhs.isLastStep
    }
}

private func nodeSignature(_ nodes: [FormNode]) -> [Int] {
    nodes.flatMap { node -> [Int] in
        guard case .section(let section) = node else { return [node.nodeID] }
        return [node.nodeID] + nodeSignature(section.fields) + [-1]
    }
}

public struct FocusRequest: Identifiable, Equatable, Sendable {
    public let key: String?
    public let id: Int
    public let summary: Bool
}
