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
        #expect(stage.depth == 3)
        stage.box.system = false
        #expect(await eventually { stage.depth == 2 })
        await settle()
        #expect(stage.depth == 2)
        stage.close()
    }

    @Test("picking an earlier step from the back menu goes back to it")
    func jumpBack() async throws {
        let model = try stepsModel()
        let stage = Stage(model)
        await settle()
        await model.next()
        await settle()
        await model.next()
        await settle()
        #expect(stage.depth == 3)
        stage.navigation?.popToRootViewController(animated: false)
        #expect(await eventually { model.structure.currentStep?.id == "a" })
        await settle()
        #expect(stage.depth == 1)
        stage.close()
    }

    @Test("a jump back stops where onBeforeStepChange refuses")
    func jumpBackRefused() async throws {
        var options = FormEngineOptions()
        options.onBeforeStepChange = { change in change.toStepId == "a" ? false : nil }
        let model = try stepsModel(options: options)
        let stage = Stage(model)
        await settle()
        await model.next()
        await settle()
        await model.next()
        await settle()
        stage.navigation?.popToRootViewController(animated: false)
        await settle(1500)
        #expect(model.structure.currentStep?.id == "b")
        #expect(await eventually { stage.depth == 2 })
        #expect(stage.navigation?.topViewController?.navigationItem.title == "Bravo")
        stage.close()
    }
}
