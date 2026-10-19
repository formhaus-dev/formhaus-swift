import FormhausCore
import FormhausUI
import SwiftUI
import Testing
import UIKit

@testable import FormhausDemo

@Suite("System step stack", .serialized)
@MainActor
struct SystemStackTests {
    @Test("each pushed page shows its own step")
    func backStack() async throws {
        let model = try stepsModel()
        let stage = Stage(model)
        await settle()
        await model.next()
        await settle()
        await model.next()
        await settle()
        let pages = stage.navigation?.viewControllers ?? []
        #expect(pages.count == 3)
        #expect(pages.map(\.navigationItem.title) == ["Alpha", "Bravo", "Charlie"])
        for (index, page) in pages.enumerated().dropFirst() {
            page.view.frame = stage.window.bounds
            page.view.layoutIfNeeded()
            let fields = axLabels(page.view).filter { ["X", "Y", "Z"].contains($0) }
            #expect(fields == [["X"], ["Y"], ["Z"]][index], "level \(index): \(fields)")
        }
        stage.navigation?.popViewController(animated: false)
        await settle()
        let middle = axLabels(stage.window).filter { ["X", "Y", "Z"].contains($0) }
        #expect(middle == ["Y"])
        #expect(model.structure.currentStep?.id == "b")
        stage.close()
    }

    @Test("replacing the model pops its pushed steps")
    func modelReplaced() async throws {
        let stage = Stage(try stepsModel())
        await settle()
        await stage.box.model.next()
        await stage.box.model.next()
        await settle()
        #expect(stage.depth == 3)
        stage.box.model = try stepsModel(values: [:])
        #expect(await eventually { stage.depth == 1 })
        stage.close()
    }

    @Test("switching to another set pops the pushed steps")
    func styleSwitched() async throws {
        let stage = Stage(try stepsModel())
        await settle()
        await stage.box.model.next()
        await settle()
        #expect(stage.depth == 2)
        stage.box.system = false
        #expect(await eventually { stage.depth == 1 })
        stage.close()
    }

    @Test("focusing a field on an earlier step pops back and focuses it")
    func focusAfterJumpBack() async throws {
        let model = try stepsModel()
        let stage = Stage(model)
        await settle()
        await model.next()
        await settle()
        await model.next()
        await settle()
        model.focus(field: "x")
        await settle(1500)
        #expect(stage.depth == 1)
        #expect(responder(stage.window) is UITextField)
        stage.close()
    }

    @Test("back is hidden while a step validates")
    func backDuringValidation() async throws {
        let model = try stepsModel(delay: true)
        let stage = Stage(model)
        await settle()
        await model.next()
        await settle()
        let pending = Task { await model.next() }
        #expect(await eventually { model.stepValidating })
        #expect(await eventually { stage.navigation?.topViewController?.navigationItem.hidesBackButton == true })
        await pending.value
        await settle()
        #expect(stage.depth == 3)
        stage.close()
    }

    @Test("a reset pops back to the first step")
    func reset() async throws {
        let model = try stepsModel()
        let stage = Stage(model)
        await settle()
        await model.next()
        await model.next()
        await settle()
        model.engine.reset()
        #expect(await eventually { stage.depth == 1 })
        stage.close()
    }
}
