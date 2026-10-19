import FormhausCore

extension ScenarioRun {
    private func index(_ step: JSONObject) -> Int {
        step["index"]?.numberValue.flatMap { Int(exactly: $0) } ?? -1
    }

    func act(_ step: JSONObject) async throws -> JSONValue? {
        let key = step["key"]?.stringValue ?? ""
        switch step["do"]?.stringValue {
        case "start": engine.start()
        case "setValue": engine.setValue(key, step["value"])
        case "setItemValue": engine.setItemValue(key, index(step), step["field"]?.stringValue ?? "", step["value"])
        case "addItem": return .bool(engine.addItem(key))
        case "removeItem": return .bool(engine.removeItem(key, index(step)))
        case "setErrors": engine.setErrors(fieldErrors(step["errors"]) ?? FieldErrors())
        case "setFieldLoading": engine.setFieldLoading(key, step["loading"]?.boolValue ?? false)
        case "cancelPendingActions": engine.cancelPendingActions()
        case "next": return .bool(try await engine.next())
        case "back": return .bool(try await engine.back())
        case "skip": return .bool(try await engine.skip(truthy(step["handler"]) ? handler(step["handler"]) : nil))
        case "submit": return .bool(try await engine.submit(handler(step["handler"])))
        case "validate": return json(engine.validate())
        case "validateField": return engine.validateField(key).map(JSONValue.string)
        case "goToStepWithField": engine.goToStepWithField(key)
        case "reset": engine.reset(step["values"]?.objectValue)
        case let name: throw ScriptError(message: "unknown action \(name ?? "nil")")
        }
        return nil
    }

    private func read(_ name: String, _ expected: JSONValue?) -> JSONValue? {
        let steps = file.definition(of: scenario)["steps"]?.arrayValue ?? []
        switch name {
        case "values": return .object(engine.values)
        case "submitValues": return .object(engine.getSubmitValues())
        case "errors": return json(engine.errors)
        case "topLevelErrors": return json(engine.topLevelErrors)
        case "stepErrors": return .object(JSONObject(engine.stepErrors.map { ($0.key, json($0.value)) }))
        case "step": return engine.currentStep.map { .string($0.id) } ?? .null
        case "stepIndex": return .number(Double(engine.currentStepIndex))
        case "steps": return json(engine.visibleSteps.map(\.id))
        case "fields": return json(engine.visibleFields.map(\.key))
        case "skipped": return json(steps.compactMap { $0["id"]?.stringValue }.filter(engine.isStepSkipped))
        case "items":
            let keys = expected?.objectValue?.keys ?? []
            return .object(JSONObject(keys.map { ($0, .number(Double(engine.items($0).count))) }))
        case "isFirstStep": return .bool(engine.isFirstStep)
        case "isLastStep": return .bool(engine.isLastStep)
        case "canGoNext": return .bool(engine.canGoNext)
        case "progress": return ["current": .number(Double(engine.progress.current)), "total": .number(Double(engine.progress.total))]
        case "submitting": return .bool(engine.submitting)
        case "stepValidating": return .bool(engine.stepValidating)
        case "fieldLoading": return .object(JSONObject(engine.fieldLoading.map { ($0.key, .bool($0.value)) }))
        case "log":
            defer { log = [] }
            return .array(log)
        default:
            failures.append("unknown expectation \(name)")
            return nil
        }
    }

    private func expect(_ index: Int, _ expectation: JSONObject) {
        let actual = expectation.map { ($0.key, read($0.key, $0.value)) }
        for (key, value) in actual { check("step \(index) expect.\(key)", value, expectation[key]) }
        if !expectation.has("log") { log = [] }
    }

    private func start(_ label: String, _ step: JSONObject) -> Flag {
        let done = Flag()
        let task = Task { @MainActor in
            let result: Outcome
            do {
                result = .success(try await act(step))
            } catch {
                result = .failure(error)
            }
            outcome(label, step, result)
            done.isSet = true
        }
        pending.append((label, task, done))
        return done
    }

    private func settle() async -> Bool {
        await drain()
        let waiting = pending
        pending = []
        for entry in waiting {
            guard entry.done.isSet else {
                failures.append("\(entry.label) never settled")
                return false
            }
            await entry.task.value
        }
        return true
    }

    func run() async throws -> [String] {
        for (index, value) in (scenario["steps"]?.arrayValue ?? []).enumerated() {
            let step = value.objectValue ?? JSONObject()
            if let expectation = step["expect"]?.objectValue {
                expect(index, expectation)
                continue
            }
            let label = "step \(index) \(step["do"]?.stringValue ?? "")"
            switch step["do"]?.stringValue {
            case "settle":
                guard await settle() else { return failures }
            case "resolve":
                try script.resolve(step["deferred"]?.stringValue ?? "")
                await drain()
            default:
                let done = start(label, step)
                if step["await"] == .bool(false) {
                    await drain()
                } else {
                    let settled = await settle(only: done)
                    guard settled else { return failures }
                }
            }
        }
        let unsettled = pending.filter { !$0.done.isSet }.map(\.label)
        if !unsettled.isEmpty { failures.append("unsettled action(s): \(unsettled.joined(separator: ", "))") }
        if !script.pending.isEmpty { failures.append("unresolved deferred reply(s): \(script.pending.joined(separator: ", "))") }
        return failures
    }

    private func settle(only done: Flag) async -> Bool {
        await drain()
        guard let position = pending.firstIndex(where: { $0.done === done }) else { return true }
        let entry = pending.remove(at: position)
        guard done.isSet else {
            failures.append("\(entry.label) never settled")
            return false
        }
        await entry.task.value
        return true
    }
}

extension JSONObject {
    init(_ pairs: [(String, JSONValue)]) {
        self.init()
        for (key, value) in pairs { self[key] = value }
    }
}
