import FormhausCore
import FormhausUI
import SwiftUI
import Testing
import UIKit

@testable import FormhausDemo

private let identified: JSONValue = [
    "id": "t", "title": "T", "submit": ["label": "Send"],
    "fields": [
        ["key": "email", "type": "email", "label": "Email"],
        ["key": "plan", "type": "radio", "label": "Plan", "options": [["value": "a", "label": "A"], ["value": "b", "label": "B"]]],
    ],
]

@Suite("System adopter options", .serialized)
@MainActor
struct SystemAdopterTests {
    @Test("both sets name fields, options, the form and the primary button after the definition id", arguments: [true, false])
    func testIds(system: Bool) async throws {
        let expected: Set = ["t.form", "t.email", "t.plan", "t.plan.a", "t.plan.b", "t.submit"]
        #expect(try await identifiers(system: system, scroller: true) == expected)
        let content = try await identifiers(system: system, scroller: false)
        #expect(content == (system ? expected : expected.subtracting(["t.form"])))
    }

    @Test("test ids are off by default")
    func testIdsOff() async throws {
        let stage = Stage(FormModel(definition: try FormDefinition(json: identified)) { _, _ in .ok })
        #expect(await eventually { axLabels(stage.window).contains("Email") })
        #expect(accessibilityIdentifiers(stage.window).filter { $0.hasPrefix("t.") }.isEmpty)
        stage.close()
    }

    private func identifiers(system: Bool, scroller: Bool) async throws -> Set<String> {
        let options = FormRendererOptions(testIds: .automatic)
        let model = FormModel(definition: try FormDefinition(json: identified), options: options) { _, _ in .ok }
        let stage = Stage(model)
        stage.box.system = system
        stage.box.scroller = scroller
        _ = await eventually { accessibilityIdentifiers(stage.window).contains("t.plan.b") }
        try? await Task.sleep(for: .milliseconds(300))
        let found = Set(accessibilityIdentifiers(stage.window).filter { $0.hasPrefix("t.") })
        stage.close()
        return found
    }

    @Test("the system set sets the title display mode only when the behavior asks for one")
    func titleDisplayMode() async throws {
        let inline = try await displayMode(.inline, host: .automatic)
        #expect(inline == .never || inline == .inline)
        #expect(try await displayMode(.large, host: .inline) == .always)
        #expect(try await displayMode(.automatic, host: .inline) == inline)
        #expect(try await displayMode(.automatic, host: .large) == .always)
        let stage = Stage(try stepsModel())
        stage.box.behavior = FormBehavior(titleDisplayMode: .off)
        #expect(await stage.shows(["X"]))
        #expect(await eventually { (stage.navigation?.topViewController?.navigationItem.title ?? "").isEmpty })
        stage.close()
    }

    private func displayMode(_ mode: TitleDisplayMode, host: NavigationBarItem.TitleDisplayMode) async throws
        -> UINavigationItem.LargeTitleDisplayMode?
    {
        let stage = Stage(try stepsModel())
        stage.box.behavior = FormBehavior(titleDisplayMode: mode)
        stage.box.hostTitleMode = host
        _ = await stage.shows(["X"])
        let item = { stage.navigation?.topViewController?.navigationItem }
        _ = await eventually { item()?.title == "P" }
        try? await Task.sleep(for: .milliseconds(300))
        let result = item()?.largeTitleDisplayMode
        stage.close()
        return result
    }
}
