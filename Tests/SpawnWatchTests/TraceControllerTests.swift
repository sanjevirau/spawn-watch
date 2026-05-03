import Foundation
import Testing
import SpawnWatchCore
@testable import SpawnWatch

@Suite("TraceController Tests")
@MainActor
struct TraceControllerTests {
    private func makeTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("spawnwatch-trace-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    @Test("startTrace sets recording state")
    func startTrace() {
        let dir = makeTempDir(); defer { cleanup(dir) }
        let controller = TraceController(store: TraceStore(directoryURL: dir))
        controller.startTrace(name: "test")
        #expect(controller.isRecording == true)
        #expect(controller.currentTrace?.name == "test")
    }

    @Test("startTrace generates a default name when blank")
    func startTraceDefaultName() {
        let dir = makeTempDir(); defer { cleanup(dir) }
        let controller = TraceController(store: TraceStore(directoryURL: dir))
        controller.startTrace(name: "")
        #expect(controller.currentTrace?.name.contains("Trace") == true)
    }

    @Test("appendIfRecording adds events while recording")
    func appendIfRecording() {
        let dir = makeTempDir(); defer { cleanup(dir) }
        let controller = TraceController(store: TraceStore(directoryURL: dir))
        controller.startTrace(name: "test")

        let e = SpawnEvent(
            eventType: .exec,
            parent: ProcessIdentity(pid: 1, name: "launchd"),
            child: ProcessIdentity(pid: 2, name: "child"),
            source: .eslogger
        )
        controller.appendIfRecording(e)
        #expect(controller.currentTrace?.events.count == 1)
    }

    @Test("appendIfRecording is a no-op when not recording")
    func appendNoOpWhenNotRecording() {
        let dir = makeTempDir(); defer { cleanup(dir) }
        let controller = TraceController(store: TraceStore(directoryURL: dir))

        let e = SpawnEvent(
            eventType: .exec,
            parent: ProcessIdentity(pid: 1, name: "launchd"),
            child: ProcessIdentity(pid: 2, name: "child"),
            source: .eslogger
        )
        controller.appendIfRecording(e)
        #expect(controller.currentTrace == nil)
    }

    @Test("stopTrace persists session and clears recording state")
    func stopTracePersists() async throws {
        let dir = makeTempDir(); defer { cleanup(dir) }
        let store = TraceStore(directoryURL: dir)
        let controller = TraceController(store: store)
        controller.startTrace(name: "save-me")

        let event = SpawnEvent(
            eventType: .exec,
            parent: ProcessIdentity(pid: 1, name: "launchd"),
            child: ProcessIdentity(pid: 2, name: "child"),
            source: .eslogger
        )
        controller.appendIfRecording(event)

        controller.stopTrace()
        #expect(controller.isRecording == false)

        // Persistence is async — wait briefly for the disk write to complete.
        for _ in 0..<20 {
            let onDisk = (try? await store.list()) ?? []
            if !onDisk.isEmpty {
                #expect(onDisk.first?.name == "save-me")
                #expect(onDisk.first?.events.count == 1)
                return
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        Issue.record("Trace was not persisted to disk within timeout")
    }

    @Test("startTrace is a no-op while a trace is already active")
    func cannotStartWhileRecording() {
        let dir = makeTempDir(); defer { cleanup(dir) }
        let controller = TraceController(store: TraceStore(directoryURL: dir))
        controller.startTrace(name: "first")
        let firstId = controller.currentTrace?.id
        controller.startTrace(name: "second")
        #expect(controller.currentTrace?.id == firstId)
        #expect(controller.currentTrace?.name == "first")
    }

    @Test("loadSavedSessions reads existing traces")
    func loadSavedSessions() async throws {
        let dir = makeTempDir(); defer { cleanup(dir) }
        let store = TraceStore(directoryURL: dir)
        let session = TraceSession(
            id: UUID(),
            name: "preexisting",
            startTime: Date(timeIntervalSince1970: 1_700_000_000)
        )
        try await store.save(session)

        let controller = TraceController(store: store)
        controller.loadSavedSessions()

        for _ in 0..<20 {
            if !controller.savedSessions.isEmpty {
                #expect(controller.savedSessions.first?.name == "preexisting")
                return
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        Issue.record("Saved sessions were not loaded within timeout")
    }
}
