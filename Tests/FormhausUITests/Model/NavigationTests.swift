@_spi(Renderer) import FormhausCore
import FormhausUI
import Testing

@Suite("Renderer actions")
@MainActor
struct NavigationTests {
    @Test("commit on an autoAdvance field moves to the next step")
    func autoAdvance() async throws {
        let form = try model(stepsDefinition, values: ["name": "Ada"])
        form.commitValue("w", forKey: "seat")
        for _ in 0..<20 where form.structure.currentStep?.id != "when" { await Task.yield() }
        #expect(form.structure.currentStep?.id == "when")
        #expect(form.structure.progress.current == 2)
        #expect(form.actions.showBack)
        #expect(form.actions.primaryLabel == "Book")
    }

    @Test("next with errors stays and focuses the first error")
    func blockedNext() async throws {
        let form = try model(stepsDefinition)
        await form.next()
        #expect(form.structure.currentStep?.id == "who")
        #expect(form.focusRequest?.key == "name")
        #expect(form.stepErrorCounts == ["who": 1])
    }

    @Test("next and back move between steps and ask for focus")
    func steps() async throws {
        let form = try model(stepsDefinition, values: ["name": "Ada"])
        #expect(form.actions.primaryLabel == "Continue")
        await form.next()
        #expect(form.structure.currentStep?.id == "when")
        #expect(form.focusRequest != nil)
        await form.back()
        #expect(form.structure.currentStep?.id == "who")
    }

    @Test("show opens the step of a field and focuses it")
    func show() async throws {
        let form = try model(stepsDefinition, values: ["name": "Ada"])
        await form.next()
        form.focus(field: "name")
        #expect(form.structure.currentStep?.id == "who")
        #expect(form.focusRequest?.key == "name")
    }

    @Test("loading blocks edits and actions")
    func loading() async throws {
        let form = try model(stepsDefinition, values: ["name": "Ada"])
        form.loading = true
        #expect(form.disabled)
        form.setValue("Bo", forKey: "name")
        await form.next()
        #expect(form.field("name").value == "Ada")
        #expect(form.structure.currentStep?.id == "who")
    }

    @Test("labels come from the renderer source, then the definition, then defaults")
    func labels() throws {
        var definition = stepsDefinition.objectValue ?? [:]
        definition["labels"] = ["back": "Zurück"]
        let source = LabelSource.catalog(["continue": "Weiter"])
        let form = try model(.object(definition), options: FormRendererOptions(labels: source))
        #expect(form.text(forLabel: "continue") == "Weiter")
        #expect(form.text(forLabel: "back") == "Zurück")
        #expect(form.text(forLabel: "stepOf", ["current": 1, "total": 2]) == "Step 1 of 2")
        #expect(form.actions.primaryLabel == "Weiter")
    }
}

@Suite("Localized forms")
@MainActor
struct LocalizedTests {
    @Test("an overlay translates texts, messages and labels")
    func overlay() async throws {
        let overlay: JSONValue = [
            "fields": ["email": ["label": "E-Mail"]], "messages": ["required": "Pflichtfeld"], "labels": ["errorSummary": "Bitte prüfen"],
        ]
        let localized = try localize(signupDefinition, overlay: overlay, lang: "de")
        let form = FormModel(localized: localized, initialValues: ["agree": true]) { _, _ in nil }
        #expect(form.text(forLabel: "errorSummary") == "Bitte prüfen")
        #expect(form.structure.visibleFields.first?.label == "E-Mail")
        await form.submit()
        #expect(form.field("email").error == "Pflichtfeld")
    }
}
