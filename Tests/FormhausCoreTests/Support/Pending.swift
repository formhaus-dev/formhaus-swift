import FormhausCore

@MainActor
final class Pending {
    private var waiter: CheckedContinuation<FieldErrors?, Never>?

    func wait() async -> FieldErrors? {
        await withCheckedContinuation { waiter = $0 }
    }

    func started() async {
        while waiter == nil { await Task.yield() }
    }

    func resolve(_ errors: FieldErrors?) {
        waiter?.resume(returning: errors)
        waiter = nil
    }
}

@MainActor
final class HookCalls {
    var contexts: [ValidateContext] = []
    var values: [JSONObject] = []
    var names: [String] = []

    func record(_ values: JSONObject, _ context: ValidateContext) {
        self.values.append(values)
        contexts.append(context)
    }

    func send(_: JSONObject, _: [String]) -> SubmitResult? {
        names.append("submit")
        return nil
    }
}

enum League {
    static let definition: JSONValue = [
        "formatVersion": "1.1", "id": "league", "title": "League", "submit": ["label": "Send"],
        "steps": [
            [
                "id": "account", "title": "Account",
                "fields": [
                    ["key": "email", "type": "email", "label": "Email", "validation": ["required": true]],
                    ["key": "plan", "type": "text", "label": "Plan"],
                    ["key": "company", "type": "text", "label": "Company", "show": [["field": "plan", "eq": "team"]]],
                ],
            ],
            [
                "id": "roster", "title": "Roster", "skip": ["label": "Skip"],
                "fields": [
                    [
                        "key": "players", "type": "group", "label": "Players",
                        "fields": [
                            ["key": "name", "type": "text", "label": "Name"],
                            ["key": "role", "type": "text", "label": "Role", "show": [["field": "name", "notEmpty": true]]],
                        ],
                    ]
                ],
            ],
            ["id": "notes", "title": "Notes", "fields": [["key": "notes", "type": "textarea", "label": "Notes"]]],
        ],
    ]

    static let values: JSONObject = [
        "email": "ada@example.com", "plan": "solo", "players": [["name": "Ada", "role": "Lead"], ["name": ""]], "notes": "Hi",
    ]

    @MainActor
    static func engine(_ options: FormEngineOptions, values: JSONObject = values) throws -> FormEngine {
        try FormEngine(definition: definition, values: values, options: options)
    }

    @MainActor
    static func pendingSubmit(_ check: Pending, _ calls: HookCalls) async throws -> (FormEngine, Task<Bool, any Error>) {
        let engine = try await onNotes(FormEngineOptions(onValidate: { _, context in context.submit ? await check.wait() : nil }))
        let submitting = Task { try await engine.submit(calls.send) }
        await check.started()
        return (engine, submitting)
    }

    @MainActor
    static func onNotes(_ options: FormEngineOptions) async throws -> FormEngine {
        let engine = try engine(options)
        try await engine.next()
        try await engine.next()
        return engine
    }
}
