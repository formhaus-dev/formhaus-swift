import FormhausCore
import Testing

@Suite("Gallery: text fields", .serialized)
@MainActor
struct TextGalleryTests {
    @Test("text-like fields in every state")
    func textFields() throws {
        try renderEntries(
            "text",
            [
                GalleryEntry(
                    name: "text",
                    field: [
                        "key": "name", "type": "text", "label": "Full name", "placeholder": "Ada Lovelace",
                        "helperText": "As on your passport",
                    ],
                    value: "Grace Hopper"),
                GalleryEntry(name: "email", field: ["key": "email", "type": "email", "label": "Email"], value: "grace@navy.mil"),
                GalleryEntry(
                    name: "phone", field: ["key": "phone", "type": "phone", "label": "Phone", "mask": "+1 (___) ___-____"],
                    value: "+1 555 0100"),
                GalleryEntry(name: "number", field: ["key": "age", "type": "number", "label": "Age"], value: 42),
                GalleryEntry(name: "password", field: ["key": "pw", "type": "password", "label": "Password"], value: "hunter22"),
                GalleryEntry(
                    name: "textarea", field: ["key": "bio", "type": "textarea", "label": "About you", "placeholder": "A few words"],
                    value: "Rear admiral, computer scientist and the mother of COBOL."),
            ])
    }
}
