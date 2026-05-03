import Foundation
import Testing
@testable import SpawnWatchCore

@Suite("ProcessRecord Tests")
@MainActor
struct ProcessRecordTests {
    private func makeRecord(
        pid: Int32 = 100,
        spawn: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> ProcessRecord {
        ProcessRecord(
            key: ProcessKey(pid: pid, spawnTime: spawn),
            identity: ProcessIdentity(pid: pid, name: "test"),
            parentKey: nil,
            spawnTime: spawn
        )
    }

    @Test("Newly created record reports alive")
    func aliveOnCreation() {
        let r = makeRecord()
        #expect(r.isAlive == true)
        #expect(r.exitTime == nil)
        #expect(r.duration == nil)
        #expect(r.wasKilled == false)
    }

    @Test("Setting exitTime computes duration")
    func durationOnExit() {
        let spawn = Date(timeIntervalSince1970: 1_700_000_000)
        let r = makeRecord(spawn: spawn)
        r.exitTime = spawn.addingTimeInterval(2.5)
        #expect(r.isAlive == false)
        #expect(r.duration == 2.5)
    }

    @Test("Records killed by signal are flagged")
    func wasKilled() {
        let r = makeRecord()
        r.terminatingSignal = 9
        #expect(r.wasKilled == true)
    }

    @Test("Records exited cleanly are not flagged as killed")
    func cleanExitNotKilled() {
        let r = makeRecord()
        r.exitCode = 0
        #expect(r.wasKilled == false)
    }

    @Test("Snapshot mirrors the record's state")
    func snapshotMirrorsState() {
        let r = makeRecord()
        r.commandLine = ["./foo", "arg"]
        r.exitTime = r.spawnTime.addingTimeInterval(1.0)
        r.exitCode = 0
        r.children = [ProcessKey(pid: 999, spawnTime: r.spawnTime)]

        let snap = r.snapshot()
        #expect(snap.key == r.key)
        #expect(snap.identity.pid == 100)
        #expect(snap.commandLine == ["./foo", "arg"])
        #expect(snap.duration == 1.0)
        #expect(snap.isAlive == false)
        #expect(snap.children.count == 1)
    }
}

@Suite("ProcessKey Tests")
struct ProcessKeyTests {
    @Test("Equal keys with same pid and ms-truncated spawn time match")
    func equalityAcrossSubMs() {
        let t1 = Date(timeIntervalSince1970: 1_700_000_000.0001)
        let t2 = Date(timeIntervalSince1970: 1_700_000_000.0009)
        let a = ProcessKey(pid: 100, spawnTime: t1)
        let b = ProcessKey(pid: 100, spawnTime: t2)
        #expect(a == b, "spawn times within the same millisecond should produce equal keys")
    }

    @Test("Different millisecond spawn times produce different keys")
    func differentMillisecondsDiffer() {
        let a = ProcessKey(pid: 100, spawnTime: Date(timeIntervalSince1970: 1_700_000_000.000))
        let b = ProcessKey(pid: 100, spawnTime: Date(timeIntervalSince1970: 1_700_000_000.005))
        #expect(a != b)
    }

    @Test("Different pids produce different keys regardless of time")
    func differentPids() {
        let t = Date()
        #expect(ProcessKey(pid: 100, spawnTime: t) != ProcessKey(pid: 101, spawnTime: t))
    }

    @Test("Description includes both pid and ms timestamp")
    func description() {
        let key = ProcessKey(pid: 42, spawnTime: Date(timeIntervalSince1970: 1234.0))
        #expect(key.description.contains("pid:42"))
        #expect(key.description.contains("@1234000"))
    }

    @Test("Codable round-trips identity")
    func codableRoundtrip() throws {
        let original = ProcessKey(pid: 555, spawnTime: Date(timeIntervalSince1970: 1_700_000_000))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProcessKey.self, from: data)
        #expect(decoded == original)
    }
}
