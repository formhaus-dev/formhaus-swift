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
        let model = FormModel(definition: try FormDefinition(json: identified)) { _, _ in .ok }
        let stage = Stage(model)
        stage.box.system = system
        let expected: Set = ["t.form", "t.email", "t.plan", "t.plan.a", "t.plan.b", "t.submit"]
        var found: Set<String> = []
        let named = await eventually {
            found = Set(accessibilityIdentifiers(stage.window))
            return expected.isSubset(of: found)
        }
        #expect(named, "\(found.sorted())")
        stage.close()
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
