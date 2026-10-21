import FormhausCore
import FormhausUI
import SwiftUI
import Testing
import UIKit

@testable import FormhausDemo

@MainActor
private final class Calls {
    var count = 0
}

@Suite("System step navigation", .serialized)
@MainActor
struct SystemNavigationTests {
    @Test("switching sets keeps the host's own screens")
    func hostScreensKept() async throws {
        let stage = Stage(try stepsModel(), deep: true)
        #expect(await stage.shows(["X"]))
        #expect(stage.depth == 2)
        await stage.box.model.next()
        #expect(await stage.shows(["Y"]))
        #expect(stage.depth == 2)
        stage.box.system = false
        #expect(await eventually { !stage.listed && stage.fields == ["Y"] })
        #expect(stage.depth == 2)
        stage.box.system = true
        #expect(await eventually { stage.listed && stage.fields == ["Y"] })
        #expect(stage.depth == 2)
        stage.close()
    }

    @Test("switching from the system set shows Back only in the bar")
    func singleBackAfterSwitch() async throws {
        let stage = Stage(try stepsModel())
        #expect(await stage.shows(["X"]))
        await stage.box.model.next()
        #expect(await stage.shows(["Y"]))
        #expect(await eventually { stage.barBack != nil })
        stage.box.system = false
        var contentBacks = 0
        let switched = await eventually {
            let backs = stage.backs
            contentBacks = max(contentBacks, backs.filter { !$0.bar }.count)
            return !stage.listed && backs.count == 1 && backs[0].bar
        }
        #expect(switched)
        #expect(contentBacks == 0)
        stage.close()
    }

    @Test("goToStep jumps back to an earlier step")
    func jumpBack() async throws {
        let model = try stepsModel()
        let stage = Stage(model)
        #expect(await stage.shows(["X"]))
        await model.next()
        await model.next()
        #expect(await stage.shows(["Z"]))
        model.goToStep("a")
        #expect(await stage.shows(["X"]))
        #expect(model.structure.currentStep?.id == "a")
        #expect(stage.depth == 1)
        stage.close()
    }

    @Test("Back refused by onBeforeStepChange stays on the step")
    func jumpBackRefused() async throws {
        let calls = Calls()
        var options = FormEngineOptions()
        options.onBeforeStepChange = { change in
            calls.count += 1
            return change.toStepId == "a" ? false : nil
        }
        let model = try stepsModel(options: options)
        let stage = Stage(model)
        #expect(await stage.shows(["X"]))
        await model.next()
        await model.next()
        #expect(await stage.shows(["Z"]))
        let asked = calls.count
        #expect(await eventually { stage.tapBack() })
        #expect(await stage.shows(["Y"]))
        #expect(await eventually { stage.tapBack() })
        #expect(await eventually { calls.count == asked + 2 })
        #expect(model.structure.currentStep?.id == "b")
        #expect(stage.fields == ["Y"])
        #expect(stage.depth == 1)
        stage.close()
    }

    @Test("the step header is a section header, not a clipped row")
    func headerOutsideRows() async throws {
        let stage = Stage(try stepsModel())
        #expect(await stage.shows(["X"]))
        let rows = collectionViews(in: stage.window).flatMap(\.visibleCells).map(\.accessibilityFrame)
        let header = axTree(stage.window).filter { ["Step 1 of 3", "Alpha"].contains($0.label) }
        #expect(header.count == 2)
        #expect(!rows.isEmpty)
        #expect(header.allSatisfy { node in node.cell.map { !rows.contains($0) } ?? true })
        stage.close()
    }
}

@MainActor
private func collectionViews(in view: UIView) -> [UICollectionView] {
    (view as? UICollectionView).map { [$0] } ?? view.subviews.flatMap { collectionViews(in: $0) }
}
