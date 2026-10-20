import FormhausCore
import FormhausUI
import SwiftUI
import Testing

@Suite("FormhausUI public API")
@MainActor
struct APISurfaceTests {
    @Test("the batteries-included and headless views build from public API")
    func views() throws {
        let definition = try FormDefinition(json: signupDefinition)
        let form = FormhausForm(definition: definition) { _, _ in .ok }
        let model = FormModel(definition: definition) { _, _ in nil }
        let field = FormhausField(model.structure.visibleFields[0], model: model)
        let views: [any View] = [form, FormhausForm(model: model), field, form.body, field.body]
        #expect(views.count == 5)
        #expect(model.pickedFile(forKey: model.structure.visibleFields[0].key) == nil)
    }
}
