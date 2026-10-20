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
        await settle()
        #expect(stage.depth == 1)
        #expect(stage.fields == ["X"])
        for expected in ["Y", "Z"] {
            await model.next()
            await settle()
            #expect(stage.depth == 1)
            #expect(stage.fields == [expected])
            #expect(stage.navigation?.topViewController?.navigationItem.title == "P")
        }
        stage.close()
    }

    @Test("bar Back goes to the previous step and the host back button returns on the first step")
    func barBack() async throws {
        let model = try stepsModel()
        let stage = Stage(model, deep: true)
        await settle()
        #expect(!stage.hostBackHidden)
        #expect(stage.barBack == nil)
        await model.next()
        await model.next()
        await settle()
        #expect(stage.hostBackHidden)
        #expect(stage.tapBack())
        await settle()
        #expect(model.structure.currentStep?.id == "b")
        #expect(stage.fields == ["Y"])
        #expect(stage.tapBack())
        await settle()
        #expect(model.structure.currentStep?.id == "a")
        #expect(stage.fields == ["X"])
        #expect(!stage.hostBackHidden)
        #expect(stage.depth == 2)
        stage.close()
    }

    @Test("replacing the model keeps the host stack")
    func modelReplaced() async throws {
        let stage = Stage(try stepsModel())
        await settle()
        await stage.box.model.next()
        await stage.box.model.next()
        await settle()
        stage.box.model = try stepsModel(values: [:])
        await settle()
        #expect(stage.depth == 1)
        #expect(stage.fields == ["X"])
        stage.close()
    }

    @Test("focusing a field on an earlier step goes back and focuses it")
    func focusAfterJumpBack() async throws {
        let model = try stepsModel()
        let stage = Stage(model)
        await settle()
        await model.next()
        await model.next()
        await settle()
        model.focus(field: "x")
        await settle(1500)
        #expect(stage.depth == 1)
        #expect(stage.fields == ["X"])
        #expect(responder(stage.window) is UITextField)
        stage.close()
    }

    @Test("host back stays hidden while a step validates")
    func backDuringValidation() async throws {
        let model = try stepsModel(delay: true)
        let stage = Stage(model, deep: true)
        await settle()
        await model.next()
        await settle()
        let pending = Task { await model.next() }
        #expect(await eventually { model.stepValidating })
        #expect(stage.hostBackHidden)
        await pending.value
        await settle()
        #expect(stage.depth == 2)
        #expect(stage.fields == ["Z"])
        stage.close()
    }

    @Test("a reset goes back to the first step")
    func reset() async throws {
        let model = try stepsModel()
        let stage = Stage(model)
        await settle()
        await model.next()
        await model.next()
        await settle()
        model.engine.reset()
        await settle()
        #expect(stage.depth == 1)
        #expect(stage.fields == ["X"])
        stage.close()
    }
}
