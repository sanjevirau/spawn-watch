import Foundation
import Testing
@testable import SpawnWatchCore

@Suite("TraceStore Tests")
struct TraceStoreTests {

    // MARK: helpers

    private func makeTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("spawnwatch-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private func makeSession(name: String = "Test trace") -> TraceSession {
        TraceSession(
            id: UUID(),
            name: name,
            startTime: Date(timeIntervalSince1970: 1_700_000_000),
            endTime: Date(timeIntervalSince1970: 1_700_000_010),
            events: [
                SpawnEvent(
                    eventType: .exec,
                    parent: ProcessIdentity(pid: 100, name: "zsh"),
                    child: ProcessIdentity(pid: 200, name: "ls"),
                    commandLine: ["ls", "-la"],
                    source: .eslogger
                )
            ],
            processes: []
        )
    }

    // MARK: tests

    @Test("Round-trips a session through save and load")
    func roundTrip() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = TraceStore(directoryURL: dir)
        let session = makeSession()

        try await store.save(session)
        let loaded = try await store.load(id: session.id)

        #expect(loaded.id == session.id)
        #expect(loaded.name == session.name)
        #expect(loaded.events.count == 1)
        #expect(loaded.events.first?.child.name == "ls")
    }

    @Test("Save creates the directory if missing")
    func createsDirectoryOnSave() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("spawnwatch-fresh-\(UUID().uuidString)/nested/path", isDirectory: true)
        defer { cleanup(dir) }
        let store = TraceStore(directoryURL: dir)
        try await store.save(makeSession())

        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir)
        #expect(exists == true)
        #expect(isDir.boolValue == true)
    }

    @Test("Save writes atomically (no orphan tmp file remains)")
    func atomicWrite() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = TraceStore(directoryURL: dir)
        let session = makeSession()
        try await store.save(session)

        let contents = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        #expect(contents.contains("\(session.id.uuidString).json"))
        #expect(contents.allSatisfy { !$0.hasSuffix(".tmp") })
    }

    @Test("List returns all saved sessions")
    func listSessions() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = TraceStore(directoryURL: dir)

        let s1 = makeSession(name: "first")
        let s2 = makeSession(name: "second")
        try await store.save(s1)
        try await store.save(s2)

        let listed = try await store.list()
        let ids = Set(listed.map(\.id))
        #expect(ids.contains(s1.id))
        #expect(ids.contains(s2.id))
    }

    @Test("Save overwrites an existing session at the same id")
    func overwriteSameId() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = TraceStore(directoryURL: dir)

        var s1 = makeSession(name: "original")
        try await store.save(s1)

        s1.name = "updated"
        try await store.save(s1)

        let loaded = try await store.load(id: s1.id)
        #expect(loaded.name == "updated")
    }

    @Test("Delete removes the session")
    func delete() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = TraceStore(directoryURL: dir)

        let session = makeSession()
        try await store.save(session)
        try await store.delete(id: session.id)

        do {
            _ = try await store.load(id: session.id)
            #expect(Bool(false), "expected load to throw after delete")
        } catch {
            #expect(true)
        }
    }

    @Test("List ignores non-JSON files in the directory")
    func ignoresNonJSON() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = TraceStore(directoryURL: dir)

        try await store.save(makeSession(name: "real"))

        let junkURL = dir.appendingPathComponent("notes.txt")
        try "ignore me".write(to: junkURL, atomically: true, encoding: .utf8)

        let listed = try await store.list()
        #expect(listed.count == 1)
        #expect(listed.first?.name == "real")
    }

    @Test("List tolerates corrupt JSON without throwing")
    func skipsCorruptFiles() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let store = TraceStore(directoryURL: dir)

        try await store.save(makeSession(name: "good"))

        let badURL = dir.appendingPathComponent("\(UUID().uuidString).json")
        try Data("{not valid json".utf8).write(to: badURL)

        let listed = try await store.list()
        #expect(listed.count == 1)
        #expect(listed.first?.name == "good")
    }
}
