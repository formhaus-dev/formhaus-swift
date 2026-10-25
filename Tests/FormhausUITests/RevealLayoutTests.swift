@_spi(Renderer) import FormhausCore
import SwiftUI
import Testing

@testable import FormhausUI

@MainActor
private func keys(_ placed: [RevealedNode]) -> [String] {
    placed.map { $0.node.field?.key ?? $0.node.section?.key ?? "" }
}

@MainActor
private func layout(_ model: FormModel, _ components: FormComponents = .standard, reveal: Bool = true) -> [RevealedNode] {
    model.revealLayout(model.structure.nodes, can: components.revealable(FormBehavior(conditionalReveal: reveal)))
}

@Suite("Revealed field layout")
@MainActor
struct RevealLayoutTests {
    @Test("fields stay in place without conditionalReveal")
    func off() throws {
        let model = try revealModel(contactReveal, ["contact": "email"])
        let placed = layout(model, reveal: false)
        #expect(keys(placed) == ["contact", "email", "notes"])
        #expect(placed.allSatisfy { $0.reveals.isEmpty })
    }

    @Test("a shown field goes under its option and every revealing option gets a slot")
    func radio() throws {
        let model = try revealModel(contactReveal, ["contact": "email"])
        let placed = layout(model)
        #expect(keys(placed) == ["contact", "notes"])
        let reveals = placed[0].reveals
        #expect(reveals.map(\.option.value) == ["email", "phone"])
        #expect(reveals.map { keys($0.nodes) } == [["email"], []])
        #expect(placed[1].reveals.isEmpty)
    }

    @Test("fields of a multiselect follow their options")
    func multiselect() throws {
        let model = try revealModel(servicesReveal, ["services": ["design", "build"]])
        let reveals = layout(model)[0].reveals
        #expect(reveals.map { keys($0.nodes) } == [["pages"], ["stack"]])
    }

    @Test("a revealed radio reveals its own fields")
    func nested() throws {
        let model = try revealModel(nestedReveal, ["delivery": "ship", "speed": "express"])
        let placed = layout(model)
        #expect(keys(placed) == ["delivery"])
        let speed = placed[0].reveals[0].nodes
        #expect(keys(speed) == ["speed"])
        #expect(speed[0].reveals.map { keys($0.nodes) } == [["deadline"]])
    }

    @Test("a revealed field scrolls to the row of its outermost block")
    func rows() throws {
        let model = try revealModel(nestedReveal, ["delivery": "ship", "speed": "express"])
        let placed = layout(model, .system)
        let sections = { (nodes: [FormNode]) in model.revealLayout(nodes, can: nil) }
        let deadline = revealRow(of: "deadline", in: placed, sections: sections)
        #expect(deadline?.choice == "delivery" && deadline?.row == "delivery/reveal/ship")
        #expect(revealRow(of: "speed", in: placed, sections: sections)?.row == "delivery/reveal/ship")
        #expect(revealRow(of: "delivery", in: placed, sections: sections) == nil)
    }

    @Test("a field revealed inside a section scrolls to the row of its choice")
    func sectionRows() throws {
        let definition: JSONValue = [
            "id": "c", "title": "C", "submit": ["label": "Send"],
            "fields": [["key": "about", "type": "section", "title": "About", "fields": contactReveal["fields"] ?? []]],
        ]
        let model = try revealModel(definition, ["contact": "email"])
        let can = FormComponents.system.revealable(FormBehavior(conditionalReveal: true))
        let row = revealRow(of: "email", in: layout(model, .system)) { model.revealLayout($0, can: can) }
        #expect(row?.choice == "contact" && row?.row == nil)
    }

    @Test("a field stays in place when its choice is not in the list")
    func parentMissing() throws {
        let model = try revealModel(contactReveal, ["contact": "email"])
        let email = model.structure.nodes.filter { $0.field?.key == "email" }
        let placed = model.revealLayout(email, can: FormComponents.standard.revealable(FormBehavior(conditionalReveal: true)))
        #expect(keys(placed) == ["email"])
    }

    @Test("a custom choice view keeps the fields in place")
    func custom() throws {
        let model = try revealModel(contactReveal, ["contact": "email"])
        let components = FormComponents.standard.field("radio") { RadioField($0) }
        let placed = layout(model, components)
        #expect(keys(placed) == ["contact", "email", "notes"])
        #expect(placed[0].reveals.isEmpty)
    }

    @Test("the system set reveals under inline choice lists only")
    func system() throws {
        let model = try revealModel(contactReveal, ["contact": "email"])
        #expect(keys(layout(model, .system)) == ["contact", "notes"])
        let picker = model.revealLayout(
            model.structure.nodes, can: FormComponents.system.revealable(FormBehavior(inlineChoiceLimit: 2, conditionalReveal: true)))
        #expect(keys(picker) == ["contact", "email", "notes"])
    }

    @Test("fields of a step reveal")
    func steps() throws {
        let definition: JSONValue = [
            "id": "s", "title": "S", "submit": ["label": "Send"],
            "steps": [
                ["id": "intro", "title": "Intro", "fields": [["key": "name", "type": "text", "label": "Name"]]],
                ["id": "contact", "title": "Contact", "fields": contactReveal["fields"] ?? []],
            ],
        ]
        let model = try revealModel(definition, ["name": "Ada", "contact": "email"])
        model.start()
        model.focus(field: "email")
        #expect(model.structure.currentStep?.id == "contact")
        #expect(keys(layout(model)) == ["contact", "notes"])
    }

    @Test("a replaced definition gets a new plan")
    func replaced() throws {
        let model = try revealModel(contactReveal, ["contact": "email"])
        #expect(keys(layout(model)) == ["contact", "notes"])
        var fields = contactReveal["fields"]?.arrayValue ?? []
        fields.swapAt(0, 3)
        model.engine.replaceDefinition(
            try FormDefinition(json: ["id": "contact", "title": "Contact", "submit": ["label": "Send"], "fields": .array(fields)]))
        #expect(keys(layout(model)) == ["notes", "email", "contact"])
    }

    @Test("fields inside a section reveal")
    func containers() throws {
        let definition: JSONValue = [
            "id": "c", "title": "C", "submit": ["label": "Send"],
            "fields": [
                ["key": "about", "type": "section", "title": "About", "fields": contactReveal["fields"] ?? []]
            ],
        ]
        let model = try revealModel(definition, ["contact": "email"])
        guard case .section(let section) = model.structure.nodes[0] else { throw RevealError.noSection }
        let placed = model.revealLayout(section.fields, can: FormComponents.standard.revealable(FormBehavior(conditionalReveal: true)))
        #expect(keys(placed) == ["contact", "notes"])
    }
}

private enum RevealError: Error {
    case noSection
}
