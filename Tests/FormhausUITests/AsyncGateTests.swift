import Testing

@testable import FormhausUI

private actor Peak {
    private var running = 0
    private(set) var highest = 0
    private(set) var finished = 0

    func enter() {
        running += 1
        highest = max(highest, running)
    }

    func leave() {
        running -= 1
        finished += 1
    }
}

@Suite("Image decode gate")
struct AsyncGateTests {
    @Test("no more than two decodes run at once however many images wait")
    func width() async {
        let gate = AsyncGate(width: 2)
        let peak = Peak()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<64 {
                group.addTask {
                    await gate.run {
                        await peak.enter()
                        for _ in 0..<8 { await Task.yield() }
                        await peak.leave()
                    }
                }
            }
        }
        #expect(await peak.highest <= 2)
        #expect(await peak.finished == 64)
    }
}
