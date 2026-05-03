import Foundation
import Testing
@testable import SpawnWatchCore

@Suite("ProcessTree Tests")
struct ProcessTreeTests {
    @Test("ProcessTreeNode stores identity")
    func nodeCreation() {
        let identity = ProcessIdentity(pid: 42, name: "test", executablePath: "/usr/bin/test")
        let node = ProcessTreeNode(identity: identity, spawnTime: Date())

        #expect(node.id.pid == 42)
        #expect(node.identity.name == "test")
        #expect(node.children.isEmpty)
        #expect(node.parent == nil)
    }

    @Test("Parent-child relationship")
    func parentChild() {
        let parent = ProcessTreeNode(identity: ProcessIdentity(pid: 1, name: "parent"))
        let child = ProcessTreeNode(identity: ProcessIdentity(pid: 2, name: "child"))

        child.parent = parent
        parent.children.append(child)

        #expect(parent.children.count == 1)
        #expect(parent.children.first?.id.pid == 2)
        #expect(child.parent?.id.pid == 1)
    }

    @Test("ProcessKey distinguishes pid reuse by spawn time")
    func pidReuse() {
        let early = ProcessKey(pid: 100, spawnTime: Date(timeIntervalSince1970: 1_700_000_000))
        let later = ProcessKey(pid: 100, spawnTime: Date(timeIntervalSince1970: 1_700_000_001))
        #expect(early != later)
        #expect(early.pid == later.pid)
    }
}

@Suite("Exit Event Parser Tests")
struct ExitEventParserTests {
    let parser = ESLoggerParser()

    @Test("Parses exit event with normal exit code")
    func cleanExit() {
        let json = """
        {
            "event_type": "ES_EVENT_TYPE_NOTIFY_EXIT",
            "process": {
                "executable": {"path": "/bin/sleep"},
                "audit_token": {"pid": 555}
            },
            "event": {
                "exit": { "stat": 0 }
            }
        }
        """
        let event = parser.parse(line: json)
        #expect(event != nil)
        #expect(event?.eventType == .exit)
        #expect(event?.exitCode == 0)
        #expect(event?.terminatingSignal == nil)
    }

    @Test("Parses exit event with non-zero exit code")
    func failedExit() {
        let json = """
        {
            "event_type": "ES_EVENT_TYPE_NOTIFY_EXIT",
            "process": {
                "executable": {"path": "/usr/bin/false"},
                "audit_token": {"pid": 1234}
            },
            "event": { "exit": { "stat": 256 } }
        }
        """
        let event = parser.parse(line: json)
        #expect(event != nil)
        #expect(event?.exitCode == 1)
        #expect(event?.terminatingSignal == nil)
    }

    @Test("Parses exit event with terminating signal")
    func killedExit() {
        let json = """
        {
            "event_type": "ES_EVENT_TYPE_NOTIFY_EXIT",
            "process": {
                "executable": {"path": "/bin/zsh"},
                "audit_token": {"pid": 9999}
            },
            "event": { "exit": { "stat": 9 } }
        }
        """
        let event = parser.parse(line: json)
        #expect(event != nil)
        #expect(event?.terminatingSignal == 9)
        #expect(event?.exitCode == nil)
    }
}

@Suite("Trace Differ Tests")
struct TraceDifferTests {
    @Test("Identifies added and removed exec signatures")
    func addedAndRemoved() {
        let baseSession = TraceSession(
            name: "A",
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 5),
            events: [
                makeExec(parent: "npm", child: "node", argv: ["node", "main.js"]),
                makeExec(parent: "node", child: "git", argv: ["git", "ls-remote"]),
            ],
            processes: []
        )
        let updatedSession = TraceSession(
            name: "B",
            startTime: Date(timeIntervalSince1970: 100),
            endTime: Date(timeIntervalSince1970: 110),
            events: [
                makeExec(parent: "npm", child: "node", argv: ["node", "main.js"]),
                makeExec(parent: "node", child: "python3", argv: ["python3", "build.py"]),
            ],
            processes: []
        )

        let differ = TraceDiffer()
        let result = differ.diff(left: baseSession, right: updatedSession)

        #expect(result.added.count == 1)
        #expect(result.added.first?.childName == "python3")
        #expect(result.removed.count == 1)
        #expect(result.removed.first?.childName == "git")
        #expect(result.unchanged.count == 1)
    }

    @Test("Argv normalization replaces transient tokens")
    func normalization() {
        let normalized = TraceDiffer.normalize(argv: [
            "/usr/bin/curl",
            "https://example.com/2026-01-15T12:34:56Z",
            "--token",
            "abcdef0123456789abcdef0123456789",
        ])
        #expect(normalized.contains("--token"))
        #expect(normalized.contains { $0.contains("<TS>") })
        #expect(normalized.contains { $0.contains("<HEX>") })
    }

    private func makeExec(parent: String, child: String, argv: [String]) -> SpawnEvent {
        SpawnEvent(
            eventType: .exec,
            parent: ProcessIdentity(pid: 100, name: parent),
            child: ProcessIdentity(pid: 200, name: child),
            commandLine: argv,
            source: .eslogger
        )
    }
}
