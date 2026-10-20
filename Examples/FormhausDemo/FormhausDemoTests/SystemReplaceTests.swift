import FormhausCore
import FormhausUI
import SwiftUI
import Testing
import UIKit

@testable import FormhausDemo

private func conditional(_ last: String) -> JSONValue {
    [
        "id": "p", "title": "P", "submit": ["label": "Send"],
        "steps": [
            [
                "id": "a", "title": "Alpha",
                "fields": [
                    ["key": "x", "type": "text", "label": "X"],
                    ["key": "secret", "type": "text", "label": "Secret", "show": [["field": "x", "eq": "open"]]],
                ],
            ],
            ["id": "b", "title": "Bravo", "fields": [["key": "y", "type": "text", "label": .string(last)]]],
        ],
    ]
}

@Suite("System steps after a definition replacement", .serialized)
@MainActor
struct SystemReplaceTests {
    @Test("an earlier step keeps hiding fields whose conditions are false")
    func earlierStepFiltered() async throws {
        let model = FormModel(definition: try FormDefinition(json: conditional("Y")), initialValues: ["x": "1"]) { _, _ in .ok }
        let stage = Stage(model)
        await settle()
        await model.next()
        await settle()
        model.engine.replaceDefinition(try FormDefinition(json: conditional("Y2")))
        await settle()
        #expect(stage.depth == 1)
        #expect(axLabels(stage.window).contains("Y2"))
        await model.back()
        await settle()
        let labels = axLabels(stage.window)
        #expect(labels.contains("X"))
        #expect(!labels.contains("Secret"))
        #expect(stage.depth == 1)
        stage.close()
    }
}
