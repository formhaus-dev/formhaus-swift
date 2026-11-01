import FormhausCore
import FormhausUI
import Testing

@Suite("Unsaved changes")
@MainActor
struct DirtyModelTests {
    @Test("isDirty follows edits, markClean and reset")
    func dirtyState() throws {
        let form = try model(signupDefinition, values: ["name": "Ada"])
        #expect(!form.isDirty)
        #expect(fires({ _ = form.isDirty }, when: { form.setValue("Grace", forKey: "name") }))
        #expect(form.dirtyKeys == ["name"])
        #expect(fires({ _ = form.dirtyKeys }, when: { form.setValue(true, forKey: "agree") }))
        #expect(form.dirtyKeys == ["agree", "name"])
        form.markClean()
        #expect(!form.isDirty)
        form.setValue("Ada", forKey: "name")
        #expect(form.dirtyKeys == ["name"])
        form.engine.reset(["name": "Lin"])
        #expect(!form.isDirty)
    }
}
