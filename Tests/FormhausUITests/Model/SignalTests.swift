@_spi(Renderer) import FormhausCore
import FormhausUI
import Testing

@Suite("Fine-grained signals")
@MainActor
struct SignalTests {
    @Test("a keystroke changes only the edited field")
    func keystroke() throws {
        let form = try model(signupDefinition)
        let email = form.field("email")
        let name = form.field("name")
        let others = {
            _ = name.value
            _ = name.error
            _ = name.loading
            _ = form.structure
            _ = form.actions
            _ = form.errorGroups
        }
        #expect(!fires(others, when: { form.setValue("a", forKey: "email") }))
        #expect(fires({ _ = email.value }, when: { form.setValue("ab", forKey: "email") }))
        #expect(
            !fires(
                {
                    _ = email.error
                    _ = email.loading
                }, when: { form.setValue("abc", forKey: "email") }))
        #expect(email.value == "abc")
        #expect(name.version == 0)
    }

    @Test("a condition change updates the structure, not unrelated fields")
    func structure() throws {
        let form = try model(signupDefinition)
        let name = form.field("name")
        let before = form.structureVersion
        #expect(fires({ _ = form.structure }, when: { form.setValue(true, forKey: "work") }))
        #expect(form.structureVersion == before + 1)
        #expect(form.structure.visibleFields.map(\.key).contains("company"))
        #expect(!fires({ _ = name.value }, when: { form.setValue(false, forKey: "work") }))
    }

    @Test("action state changes only when its output changes")
    func actions() throws {
        let form = try model(signupDefinition)
        #expect(form.actions.primaryDisabled)
        #expect(!fires({ _ = form.actions }, when: { form.setValue("Ada", forKey: "name") }))
        #expect(fires({ _ = form.actions }, when: { form.setValue(true, forKey: "agree") }))
        #expect(!form.actions.primaryDisabled)
        #expect(form.actions.primaryLabel == "Create")
    }

    @Test("values signal and onValuesChange fire once per change")
    func values() throws {
        var emitted: [JSONObject] = []
        let form = try model(signupDefinition, options: FormRendererOptions(onValuesChange: { emitted.append($0) }))
        form.start()
        let start = form.valuesVersion
        form.setValue("A", forKey: "name")
        form.setValue("A", forKey: "name")
        #expect(form.valuesVersion == start + 1)
        #expect(emitted.count == 2)
        #expect(emitted.last?["name"] == "A")
    }

    @Test("snapshot counters follow the engine")
    func counters() throws {
        let form = try model(signupDefinition)
        form.setValue("A", forKey: "name")
        #expect(form.version == form.engine.version)
        #expect(form.field("name").version == 1)
    }

    @Test("a failed submit counts an invalid attempt and asks for focus on the first error")
    func invalidSubmit() async throws {
        let form = try model(signupDefinition, values: ["agree": true])
        await form.submit()
        #expect(form.invalidAttempts == 1)
        #expect(form.focusRequest?.key == "email")
        #expect(form.field("email").error == "This field is required")
        #expect(form.errorGroups.flatMap(\.entries).map(\.label) == ["Email"])
        await form.submit()
        #expect(form.invalidAttempts == 2)
    }

    @Test("a disabled submit does not run")
    func disabledSubmit() async throws {
        var sent = false
        let form = try model(signupDefinition, values: ["email": "a@b.co"]) { _, _ in
            sent = true
            return nil
        }
        await form.submit()
        #expect(!sent)
        #expect(form.invalidAttempts == 0)
    }

    @Test("server errors map to fields and form-level errors")
    func serverErrors() async throws {
        let form = try model(signupDefinition, values: ["email": "a@b.co", "agree": true]) { _, _ in
            .rejected(errors: ["email": "Taken", "nope": "Unknown"], formErrors: ["Try later"])
        }
        await form.submit()
        #expect(form.field("email").error == "Taken")
        #expect(form.topLevelErrors == ["Try later", "Unknown"])
        #expect(form.focusRequest?.key == "email")
    }

    @Test("a thrown submit shows an action error")
    func thrownSubmit() async throws {
        struct Down: Error {}
        let form = try model(signupDefinition, values: ["email": "a@b.co", "agree": true]) { _, _ in throw Down() }
        await form.submit()
        #expect(form.actionError == "Form action failed")
    }
}
