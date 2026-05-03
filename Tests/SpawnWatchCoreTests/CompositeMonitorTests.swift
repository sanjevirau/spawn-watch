import Foundation
import Testing
@testable import SpawnWatchCore

@Suite("DedupeBox Tests")
struct DedupeBoxTests {
    private func event(pid: Int32, type: EventType) -> SpawnEvent {
        SpawnEvent(
            eventType: type,
            parent: ProcessIdentity(pid: 1, name: "launchd"),
            child: ProcessIdentity(pid: pid, name: "child"),
            source: .eslogger
        )
    }

    @Test("Emits the first event seen for a (pid, type) tuple")
    func firstEventEmits() async {
        let box = DedupeBox(window: 0.5)
        let emitted = await box.shouldEmit(event(pid: 100, type: .exec))
        #expect(emitted == true)
    }

    @Test("Suppresses immediate duplicate within the window")
    func suppressesDuplicate() async {
        let box = DedupeBox(window: 0.5)
        _ = await box.shouldEmit(event(pid: 100, type: .exec))
        let secondEmit = await box.shouldEmit(event(pid: 100, type: .exec))
        #expect(secondEmit == false)
    }

    @Test("Different event types for same pid are not deduplicated")
    func distinctTypesEmitSeparately() async {
        let box = DedupeBox(window: 0.5)
        _ = await box.shouldEmit(event(pid: 100, type: .exec))
        let forkEmit = await box.shouldEmit(event(pid: 100, type: .fork))
        let exitEmit = await box.shouldEmit(event(pid: 100, type: .exit))
        #expect(forkEmit == true)
        #expect(exitEmit == true)
    }

    @Test("Different pids do not collide")
    func distinctPids() async {
        let box = DedupeBox(window: 0.5)
        _ = await box.shouldEmit(event(pid: 100, type: .exec))
        let secondPid = await box.shouldEmit(event(pid: 200, type: .exec))
        #expect(secondPid == true)
    }

    @Test("After the window expires, emission resumes")
    func windowExpiry() async throws {
        let box = DedupeBox(window: 0.05)
        _ = await box.shouldEmit(event(pid: 300, type: .exec))
        try await Task.sleep(for: .milliseconds(80))
        let again = await box.shouldEmit(event(pid: 300, type: .exec))
        #expect(again == true)
    }
}
