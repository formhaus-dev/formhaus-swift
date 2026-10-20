@_spi(Renderer) import FormhausCore
import FormhausUI
import Observation

@MainActor
final class Flag: @unchecked Sendable {
    var fired = false
}

@MainActor
func fires(_ read: () -> Void, when change: () -> Void) -> Bool {
    let flag = Flag()
    withObservationTracking(read) {
        MainActor.assumeIsolated { flag.fired = true }
    }
    change()
    return flag.fired
}

@MainActor
func eventually(within limit: Duration = .seconds(5), _ condition: @MainActor () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + limit
    while !condition() {
        guard ContinuousClock.now < deadline else { return false }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return true
}

@MainActor
func model(
    _ definition: JSONValue, values: JSONObject = [:], options: FormRendererOptions = FormRendererOptions(),
    onSubmit: @escaping SubmitHandler = { _, _ in nil }
) throws -> FormModel {
    FormModel(definition: try FormDefinition(json: definition), initialValues: values, options: options, onSubmit: onSubmit)
}

let signupDefinition: JSONValue = [
    "id": "signup", "title": "Sign up", "submit": ["label": "Create", "disabled": [["field": "agree", "neq": true]]],
    "fields": [
        ["key": "email", "type": "email", "label": "Email", "validation": ["required": true]],
        ["key": "name", "type": "text", "label": "Name"],
        ["key": "company", "type": "text", "label": "Company", "show": [["field": "work", "eq": true]]],
        ["key": "work", "type": "checkbox", "label": "Work account"],
        ["key": "agree", "type": "checkbox", "label": "I agree"],
    ],
]

let stepsDefinition: JSONValue = [
    "id": "trip", "title": "Trip", "submit": ["label": "Book"],
    "steps": [
        [
            "id": "who", "title": "Who",
            "fields": [
                ["key": "name", "type": "text", "label": "Name", "validation": ["required": true]],
                [
                    "key": "seat", "type": "radio", "label": "Seat", "autoAdvance": true,
                    "options": [["value": "a", "label": "Aisle"], ["value": "w", "label": "Window"]],
                ],
            ],
        ],
        ["id": "when", "title": "When", "fields": [["key": "date", "type": "date", "label": "Date"]]],
    ],
]
