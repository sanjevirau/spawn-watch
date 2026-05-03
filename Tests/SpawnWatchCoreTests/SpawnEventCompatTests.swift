import Foundation
import Testing
@testable import SpawnWatchCore

@Suite("SpawnEvent Backward-Compat Tests")
struct SpawnEventCompatTests {
    let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    @Test("Decodes a v0.1-shaped event (no spawnTime, no exit fields)")
    func decodeMinimalLegacyEvent() throws {
        let json = """
        {
            "id": "9D1A7046-E35C-4018-AA07-C0C691792EAE",
            "timestamp": "2026-04-17T13:53:37Z",
            "eventType": "exec",
            "parent": {
                "pid": 1,
                "name": "launchd"
            },
            "child": {
                "pid": 200,
                "name": "ls"
            },
            "commandLine": ["ls"],
            "source": "polling",
            "relationship": "System"
        }
        """
        let data = Data(json.utf8)
        let event = try decoder.decode(SpawnEvent.self, from: data)
        #expect(event.eventType == .exec)
        #expect(event.parent.spawnTime == nil)
        #expect(event.child.spawnTime == nil)
        #expect(event.exitCode == nil)
        #expect(event.terminatingSignal == nil)
        #expect(event.relationship == .system)
    }

    @Test("Decodes an event missing relationship (defaults to .unknown)")
    func decodesEventWithoutRelationship() throws {
        let json = """
        {
            "id": "9D1A7046-E35C-4018-AA07-C0C691792EAE",
            "timestamp": "2026-04-17T13:53:37Z",
            "eventType": "fork",
            "parent": {"pid": 1, "name": "launchd"},
            "child": {"pid": 2, "name": "child"},
            "source": "eslogger"
        }
        """
        let event = try decoder.decode(SpawnEvent.self, from: Data(json.utf8))
        #expect(event.relationship == .unknown)
    }

    @Test("Loads the bundled v0.1 export fixture if present")
    func decodesBundledFixture() throws {
        let candidates = [
            "/Users/sanjevirau/conductor/workspaces/spawn-app/tokyo/.context/attachments/spawnwatch_NXPowerLite_Desktop_2026-04-17_215416.json",
            "/Users/sanjevirau/conductor/workspaces/spawn-app/tokyo/.context/attachments/spawnwatch_unknown_2026-04-17_214452.json",
        ]
        for path in candidates {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let events = try decoder.decode([SpawnEvent].self, from: data)
            #expect(!events.isEmpty)
            #expect(events.allSatisfy { $0.eventType == .exec || $0.eventType == .fork })
        }
    }

    @Test("Encodes and re-decodes preserving new fields")
    func roundTripWithNewFields() throws {
        let event = SpawnEvent(
            eventType: .exit,
            parent: ProcessIdentity(pid: 1, name: "kernel"),
            child: ProcessIdentity(
                pid: 200,
                name: "ls",
                executablePath: "/bin/ls",
                spawnTime: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            source: .eslogger,
            exitCode: nil,
            terminatingSignal: 9
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(event)
        let decoded = try decoder.decode(SpawnEvent.self, from: data)
        #expect(decoded.eventType == .exit)
        #expect(decoded.terminatingSignal == 9)
        #expect(decoded.child.spawnTime != nil)
    }

    @Test("ProcessIdentity decodes without spawnTime (legacy)")
    func processIdentityLegacy() throws {
        let json = """
        {"pid": 100, "name": "zsh"}
        """
        let id = try decoder.decode(ProcessIdentity.self, from: Data(json.utf8))
        #expect(id.pid == 100)
        #expect(id.spawnTime == nil)
    }
}
