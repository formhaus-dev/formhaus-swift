import FormhausCore
import Foundation

@MainActor
final class SnapshotState {
    var last: FormSnapshot?
    var turn = 0
    var pending = false
}

@MainActor
private final class SentFlag {
    var value = false
}

extension FormModel {
    func emitValues() {
        guard let onValuesChange = options.onValuesChange else { return }
        let values = engine.values
        guard values != emittedValues else { return }
        emittedValues = values
        onValuesChange(values)
    }

    func snapshotChanged() {
        guard options.onSnapshotChange != nil, !snapshots.pending else { return }
        snapshots.pending = true
        let turn = snapshots.turn
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated { self?.emitSnapshot(turn) }
        }
    }

    func clearingSnapshot(_ send: (@escaping SubmitHandler) async throws -> Bool) async throws -> Bool {
        let sent = SentFlag()
        let handler = submitHandler
        do {
            let done = try await send { values, skipped in
                sent.value = true
                return try await handler(values, skipped)
            }
            if done && sent.value { clearSnapshot() }
            return done
        } catch let error as FormLifecycleError where error.phase == .afterSubmit {
            clearSnapshot()
            throw error
        }
    }

    private func emitSnapshot(_ turn: Int) {
        guard snapshots.turn == turn else { return }
        snapshots.pending = false
        let next = engine.snapshot()
        guard next != snapshots.last else { return }
        snapshots.last = next
        options.onSnapshotChange?(next)
    }

    private func clearSnapshot() {
        snapshots.turn += 1
        snapshots.pending = false
        snapshots.last = engine.snapshot()
        options.onSnapshotChange?(nil)
    }
}
