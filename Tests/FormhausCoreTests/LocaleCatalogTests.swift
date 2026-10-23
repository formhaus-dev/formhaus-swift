import Foundation
import Testing

@_spi(Renderer) @testable import FormhausCore

private func characters(_ one: String, _ few: String, _ many: String, _ other: String) -> LocaleText {
    .plural(PluralForms(one: one, few: few, many: many, other: other))
}

private let russian = LocaleCatalog(
    locale: "ru",
    messages: [
        .required: "Обязательное поле",
        .minLength: characters(
            "Не менее {min} символа", "Не менее {min} символов", "Не менее {min} символов", "Не менее {min} символа"),
    ],
    labels: [
        "continue": "Далее", "stepTitle": "Шаг {index}",
        "stepErrors": characters("{count} ошибка", "{count} ошибки", "{count} ошибок", "{count} ошибки"),
    ])

private func form(_ minLength: Int, _ extra: JSONObject = [:]) -> JSONValue {
    var form: JSONObject = [
        "id": "f", "title": "F", "submit": ["label": "Send"],
        "fields": [
            ["key": "name", "type": "text", "label": "Name", "validation": ["required": true, "minLength": .number(Double(minLength))]]
        ],
    ]
    for (key, value) in extra { form[key] = value }
    return .object(form)
}

@MainActor
private func minLengthError(
    _ minLength: Int, _ locale: [LocaleCatalog], messages: MessageSource? = nil, extra: JSONObject = [:], value: JSONValue = "a"
) throws -> String? {
    let engine = try FormEngine(
        definition: form(minLength, extra), values: ["name": value], options: FormEngineOptions(messages: messages, locale: locale))
    return engine.validate()["name"]
}

@Suite("Locale catalogs")
@MainActor
struct LocaleCatalogTests {
    @Test("picks the Russian plural form by the min param")
    func russianPlurals() throws {
        #expect(try minLengthError(3, [russian]) == "Не менее 3 символов")
        #expect(try minLengthError(5, [russian]) == "Не менее 5 символов")
        #expect(try minLengthError(21, [russian]) == "Не менее 21 символа")
        #expect(try minLengthError(2, [russian], value: nil) == "Обязательное поле")
    }

    @Test("picks the French one, many and other forms")
    func frenchPlurals() throws {
        let french = LocaleCatalog(
            locale: "fr",
            messages: [
                .minLength: .plural(
                    PluralForms(one: "Au moins {min} caractère", many: "Au moins {min} de caractères", other: "Au moins {min} caractères")),
                .maxLength: .plural(PluralForms(one: "Au plus {max} caractère", other: "Au plus {max} caractères")),
            ])
        let tooLong = try FormEngine(
            definition: [
                "id": "f", "submit": ["label": "Send"],
                "fields": [["key": "name", "type": "text", "label": "Name", "validation": ["maxLength": 1]]],
            ], values: ["name": "ab"], options: FormEngineOptions(locale: [french]))
        #expect(tooLong.validate()["name"] == "Au plus 1 caractère")
        #expect(try minLengthError(2, [french]) == "Au moins 2 caractères")
        #expect(try minLengthError(1_000_000, [french]) == "Au moins 1\u{202F}000\u{202F}000 de caractères")
    }

    @Test("uses the other form in Japanese and formats numbers for the locale")
    func numbers() throws {
        let japanese = LocaleCatalog(locale: "ja", messages: [.minLength: .plural(PluralForms(other: "{min}文字以上で入力してください"))])
        #expect(try minLengthError(2, [japanese]) == "2文字以上で入力してください")
        let german = LocaleCatalog(locale: "de", messages: [.minLength: "Mindestens {min} Zeichen"])
        #expect(try minLengthError(12_000, [german]) == "Mindestens 12.000 Zeichen")
        var unknown = german
        unknown.locale = "not a tag"
        #expect(try minLengthError(12_000, [unknown]) == "Mindestens 12,000 Zeichen")
    }

    @Test("takes the first catalog that has the key, then the built-in English")
    func order() throws {
        let regional = LocaleCatalog(locale: "fr-CA", messages: [.required: "Champ requis"])
        let french = LocaleCatalog(locale: "fr", messages: [.required: "Obligatoire", .minLength: "Au moins {min}"])
        #expect(try minLengthError(2, [regional, french], value: nil) == "Champ requis")
        #expect(try minLengthError(4, [regional, french]) == "Au moins 4")
        #expect(try minLengthError(4, []) == "Minimum length is 4")
    }

    @Test("ranks the messages option over definition messages over the catalog")
    func precedence() throws {
        let own: JSONObject = ["messages": ["minLength": "Definition {min}"]]
        #expect(try minLengthError(4, [russian], extra: own) == "Definition 4")
        #expect(try minLengthError(4, [russian], messages: .catalog(["minLength": "Option {min}"]), extra: own) == "Option 4")
    }

    @Test("reads the locale when it changes after the engine was created")
    func liveLocale() throws {
        let engine = try FormEngine(definition: form(4), values: ["name": "a"])
        #expect(engine.validate()["name"] == "Minimum length is 4")
        #expect(engine.label("continue", nil) == "Continue")
        engine.locale = [russian]
        #expect(engine.validate()["name"] == "Не менее 4 символов")
        #expect(engine.label("continue", nil) == "Далее")
    }

    @Test("resolves labels with the same precedence")
    func labels() async throws {
        let steps: JSONValue = [
            ["id": "one", "title": "", "fields": form(1)["fields"] ?? []],
            ["id": "two", "title": "Two", "fields": [["key": "note", "type": "text", "label": "Note"]]],
        ]
        let engine = try FormEngine(
            definition: ["id": "f", "title": "F", "submit": ["label": "Send"], "steps": steps],
            options: FormEngineOptions(locale: [russian]))
        #expect(engine.label("stepErrors", nil, ["count": 3]) == "3 ошибки")
        #expect(engine.label("stepErrors", nil, ["count": 5]) == "5 ошибок")
        #expect(engine.label("continue", .catalog(["continue": "Prop"])) == "Prop")
        #expect(engine.label("back", nil) == "Back")
        #expect(engine.actionsState(nil).primaryLabel == "Далее")
        try await engine.next()
        #expect(errorSummary(engine).groups.first?.title == "Шаг 1")
    }

    @Test("ignores catalogs without a matching text")
    func broken() throws {
        let broken = try #require(LocaleCatalog(json: ["locale": "ru", "messages": ["minLength": ["one": "x"]], "labels": [:]]))
        #expect(broken.messages.isEmpty)
        let empty = LocaleCatalog(locale: "ru", messages: [.minLength: .plural(PluralForms(few: "", other: "x"))])
        #expect(try minLengthError(4, [broken, empty, russian]) == "Не менее 4 символов")
    }

    @Test("picks the CLDR plural forms of each shipped language")
    func categories() {
        let cases: [(String, [Double], String)] = [
            ("en", [1], "one"), ("en", [0, 2, 1.5], "other"), ("de", [1], "one"), ("de", [1.5], "other"),
            ("es", [1], "one"), ("es", [1_000_000, 2_000_000], "many"), ("es", [0, 1.5, 1_000_001], "other"),
            ("it", [1], "one"), ("it", [1_000_000], "many"), ("fr", [0, 1, 1.5], "one"), ("fr", [1_000_000], "many"),
            ("fr", [2, 1_000_000.5], "other"), ("pt", [0, 1.5], "one"), ("pt", [3], "other"), ("ja", [1, 1_000_000], "other"),
            ("zh", [1], "other"), ("ru", [1, 21, 101], "one"), ("ru", [2, 24, 102], "few"), ("ru", [0, 5, 11, 12, 14, 111], "many"),
            ("ru", [1.5], "other"), ("uk", [31], "one"), ("uk", [13], "many"), ("xx", [1], "other"),
            ("pt-PT", [1], "one"), ("pt-PT", [0, 1.5, 2], "other"), ("pt-PT", [1_000_000], "many"), ("pt-BR", [0], "one"),
            ("es-419", [0], "other"), ("fr-CA", [0], "one"), ("en-GB", [0], "other"), ("it-CH", [1_000_000], "many"),
        ]
        for (language, numbers, category) in cases {
            for number in numbers { #expect(pluralCategory(number, Locale(identifier: language)) == category, "\(language) \(number)") }
        }
    }
}
