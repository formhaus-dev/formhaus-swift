import FormhausCore
import FormhausUI
import SwiftUI
import Testing
import UIKit

@testable import FormhausDemo

@Suite("System step navigation", .serialized)
@MainActor
struct SystemNavigationTests {
    @Test("switching sets keeps the host's own screens")
    func hostScreensKept() async throws {
        let stage = Stage(try stepsModel(), deep: true)
        await settle()
        #expect(stage.depth == 2)
        await stage.box.model.next()
        await settle()
        #expect(stage.depth == 2)
        stage.box.system = false
        await settle()
        #expect(stage.depth == 2)
        #expect(stage.fields == ["Y"])
        stage.box.system = true
        await settle()
        #expect(stage.depth == 2)
        #expect(stage.fields == ["Y"])
        stage.close()
    }

    @Test("goToStep jumps back to an earlier step")
    func jumpBack() async throws {
        let model = try stepsModel()
        let stage = Stage(model)
        await settle()
        await model.next()
        await model.next()
        await settle()
        model.goToStep("a")
        await settle()
        #expect(model.structure.currentStep?.id == "a")
        #expect(stage.depth == 1)
        #expect(stage.fields == ["X"])
        stage.close()
    }

    @Test("Back refused by onBeforeStepChange stays on the step")
    func jumpBackRefused() async throws {
        var options = FormEngineOptions()
        options.onBeforeStepChange = { change in change.toStepId == "a" ? false : nil }
        let model = try stepsModel(options: options)
        let stage = Stage(model)
        await settle()
        await model.next()
        await model.next()
        await settle()
        #expect(stage.tapBack())
        await settle()
        #expect(stage.tapBack())
        await settle()
        #expect(model.structure.currentStep?.id == "b")
        #expect(stage.depth == 1)
        #expect(stage.fields == ["Y"])
        stage.close()
    }
}
