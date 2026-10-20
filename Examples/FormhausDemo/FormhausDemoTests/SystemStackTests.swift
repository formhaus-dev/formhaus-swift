import FormhausCore
import FormhausUI
import SwiftUI
import Testing
import UIKit

@testable import FormhausDemo

@Suite("System steps in place", .serialized)
@MainActor
struct SystemStackTests {
    @Test("moving through steps keeps one page and shows each step")
    func inPlace() async throws {
        let model = try stepsModel()
        let stage = Stage(model)
        #expect(await stage.shows(["X"]))
        #expect(stage.depth == 1)
        for expected in ["Y", "Z"] {
            await model.next()
            #expect(await stage.shows([expected]))
            #expect(stage.depth == 1)
            #expect(await eventually { stage.navigation?.topViewController?.navigationItem.title == "P" })
        }
        stage.close()
    }

    @Test("bar Back goes to the previous step and the host back button returns on the first step")
    func barBack() async throws {
        let model = try stepsModel()
        let stage = Stage(model, deep: true)
        #expect(await stage.shows(["X"]))
        #expect(!stage.hostBackHidden)
        #expect(stage.barBack == nil)
        await model.next()
        await model.next()
        #expect(await stage.shows(["Z"]))
        #expect(await eventually { stage.hostBackHidden })
        #expect(await eventually { stage.tapBack() })
        #expect(await stage.shows(["Y"]))
        #expect(model.structure.currentStep?.id == "b")
        #expect(await eventually { stage.tapBack() })
        #expect(await stage.shows(["X"]))
        #expect(model.structure.currentStep?.id == "a")
        #expect(await eventually { !stage.hostBackHidden })
        #expect(stage.depth == 2)
        stage.close()
    }

    @Test("replacing the model keeps the host stack")
    func modelReplaced() async throws {
        let stage = Stage(try stepsModel())
        #expect(await stage.shows(["X"]))
        await stage.box.model.next()
        await stage.box.model.next()
        #expect(await stage.shows(["Z"]))
        stage.box.model = try stepsModel(values: [:])
        #expect(await stage.shows(["X"]))
        #expect(stage.depth == 1)
        stage.close()
    }

    @Test("focusing a field on an earlier step goes back and focuses it")
    func focusAfterJumpBack() async throws {
        let model = try stepsModel()
        let stage = Stage(model)
        #expect(await stage.shows(["X"]))
        await model.next()
        await model.next()
        #expect(await stage.shows(["Z"]))
        model.focus(field: "x")
        #expect(await stage.shows(["X"]))
        #expect(await eventually { responder(stage.window) is UITextField })
        #expect(stage.depth == 1)
        stage.close()
    }

    @Test("host back stays hidden while a step validates")
    func backDuringValidation() async throws {
        let model = try stepsModel(delay: true)
        let stage = Stage(model, deep: true)
        #expect(await stage.shows(["X"]))
        await model.next()
        #expect(await stage.shows(["Y"]))
        let pending = Task { await model.next() }
        #expect(await eventually { model.stepValidating })
        #expect(await eventually { stage.hostBackHidden })
        #expect(model.stepValidating)
        await pending.value
        #expect(await stage.shows(["Z"]))
        #expect(stage.depth == 2)
        stage.close()
    }

    @Test("a reset goes back to the first step")
    func reset() async throws {
        let model = try stepsModel()
        let stage = Stage(model)
        #expect(await stage.shows(["X"]))
        await model.next()
        await model.next()
        #expect(await stage.shows(["Z"]))
        model.engine.reset()
        #expect(await stage.shows(["X"]))
        #expect(stage.depth == 1)
        stage.close()
    }
}
