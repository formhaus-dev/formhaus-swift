import AppKit
import FormhausCore
import FormhausUI
import SwiftUI
import Testing

private let account: JSONValue = [
    "formatVersion": "1.4", "id": "account", "title": "Account", "submit": ["label": "Save"],
    "fields": [
        ["key": "intro", "type": "section", "title": "", "fields": [["key": "notice", "type": "x-notice", "label": "Notice"]]],
        ["key": "name", "type": "text", "label": "Name"],
        [
            "key": "danger", "type": "section", "title": "",
            "fields": [["key": "deleteAccount", "type": "x-delete-account", "label": "Delete account"]],
        ],
    ],
]

private let stay: JSONValue = [
    "id": "stay", "title": "Stay", "submit": ["label": "Book"],
    "fields": [
        [
            "key": "dates", "type": "section", "title": "Dates",
            "fields": [
                ["key": "checkIn", "type": "date", "label": "Check-in"],
                ["key": "checkOut", "type": "date", "label": "Check-out"],
            ],
        ]
    ],
]

@MainActor
private final class RecipeLog {
    var shown: [String] = []
    var deletes = 0
}

private func nights(_ checkIn: JSONValue?, _ checkOut: JSONValue?) -> Int? {
    let strategy = Date.ISO8601FormatStyle().year().month().day()
    guard let start = checkIn?.stringValue.flatMap({ try? strategy.parse($0) }),
        let end = checkOut?.stringValue.flatMap({ try? strategy.parse($0) }),
        let days = Calendar(identifier: .gregorian).dateComponents([.day], from: start, to: end).day, days > 0
    else { return nil }
    return days
}

private struct NightsFooter: View {
    let model: FormModel
    let log: RecipeLog

    var body: some View {
        let text = nights(model.field("checkIn").value, model.field("checkOut").value).map { $0 == 1 ? "1 night" : "\($0) nights" } ?? ""
        Text(verbatim: text)
            .onAppear { log.shown.append(text) }
            .onChange(of: text) { _, next in log.shown.append(next) }
    }
}

@Suite("Recipes", .serialized)
@MainActor
struct RecipeTests {
    @Test("custom field types in sections put a notice above and a delete button below the system fields")
    func contentAroundFields() throws {
        let log = RecipeLog()
        let definition = try FormDefinition(json: account)
        #expect(checkDefinition(account).map(\.code.rawValue) == [])
        let model = FormModel(definition: definition) { _, _ in .ok }
        let components = FormComponents.system
            .field("x-notice") { _ in
                Label("Changes apply after review.", systemImage: "info.circle").onAppear { log.shown.append("notice") }
            }
            .field("x-delete-account") { _ in
                Button("Delete account", role: .destructive) { log.deletes += 1 }.onAppear { log.shown.append("delete") }
            }
        let view = NavigationStack { FormhausForm(model: model) }.formhausComponents(components)
        settle(host(view, width: 520, height: 900))
        #expect(log.shown.contains("notice"))
        #expect(log.shown.contains("delete"))
        #expect(model.engine.getSubmitValues().keys.isEmpty)
    }

    @Test("a section footer computed from the values of a caller-owned model follows the values")
    func computedFooter() throws {
        let log = RecipeLog()
        let model = FormModel(definition: try FormDefinition(json: stay)) { _, _ in .ok }
        let components = FormComponents.system.section { context in
            Section {
                context.content
            } header: {
                Text(verbatim: context.title)
            } footer: {
                if context.section.key == "dates" { NightsFooter(model: model, log: log) }
            }
        }
        let view = NavigationStack { FormhausForm(model: model) }.formhausComponents(components)
        let shown = host(view, width: 520, height: 900)
        settle(shown)
        #expect(log.shown.last?.isEmpty == true)
        model.engine.setValue("checkIn", "2026-11-02")
        model.engine.setValue("checkOut", "2026-11-05")
        settle(shown)
        #expect(log.shown.last == "3 nights")
        model.engine.setValue("checkOut", "2026-11-03")
        settle(shown)
        #expect(log.shown.last == "1 night")
    }
}
