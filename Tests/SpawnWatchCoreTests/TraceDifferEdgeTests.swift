import Foundation
import Testing
@testable import SpawnWatchCore

@Suite("TraceDiffer Edge Cases")
struct TraceDifferEdgeTests {
    private func session(name: String, events: [SpawnEvent], duration: TimeInterval = 1.0) -> TraceSession {
        TraceSession(
            id: UUID(),
            name: name,
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: duration),
            events: events,
            processes: []
        )
    }

    private func exec(parent: String, child: String, args: [String]) -> SpawnEvent {
        SpawnEvent(
            eventType: .exec,
            parent: ProcessIdentity(pid: 1, name: parent),
            child: ProcessIdentity(pid: 2, name: child),
            commandLine: args,
            source: .eslogger
        )
    }

    @Test("Empty traces produce empty buckets")
    func emptyTraces() {
        let differ = TraceDiffer()
        let result = differ.diff(left: session(name: "a", events: []), right: session(name: "b", events: []))
        #expect(result.added.isEmpty)
        #expect(result.removed.isEmpty)
        #expect(result.unchanged.isEmpty)
    }

    @Test("Identical traces produce only unchanged entries")
    func identicalTraces() {
        let differ = TraceDiffer()
        let events = [exec(parent: "zsh", child: "ls", args: ["ls", "-la"])]
        let a = session(name: "a", events: events)
        let b = session(name: "b", events: events)
        let result = differ.diff(left: a, right: b)
        #expect(result.added.isEmpty)
        #expect(result.removed.isEmpty)
        #expect(result.unchanged.count == 1)
    }

    @Test("Diff ignores fork and exit events, only considers exec")
    func ignoresNonExec() {
        let differ = TraceDiffer()
        let leftEvents: [SpawnEvent] = [
            SpawnEvent(eventType: .fork,
                parent: ProcessIdentity(pid: 1, name: "zsh"),
                child: ProcessIdentity(pid: 2, name: "fork-only"),
                source: .eslogger),
            SpawnEvent(eventType: .exit,
                parent: ProcessIdentity(pid: 1, name: "zsh"),
                child: ProcessIdentity(pid: 2, name: "exit-only"),
                source: .eslogger),
        ]
        let result = differ.diff(left: session(name: "a", events: leftEvents),
                                 right: session(name: "b", events: []))
        #expect(result.removed.isEmpty)
    }

    @Test("Counts repeated occurrences correctly")
    func countsOccurrences() {
        let differ = TraceDiffer()
        let events = (0..<5).map { _ in
            exec(parent: "make", child: "clang", args: ["clang", "-c", "src.c"])
        }
        let result = differ.diff(left: session(name: "a", events: events),
                                 right: session(name: "b", events: events))
        let entry = result.unchanged.first
        #expect(entry?.occurrences == 5)
    }

    @Test("Duration delta is signed")
    func durationDelta() {
        let differ = TraceDiffer()
        let a = session(name: "a", events: [], duration: 5)
        let b = session(name: "b", events: [], duration: 12)
        let result = differ.diff(left: a, right: b)
        #expect(result.durationDelta == 7)
    }

    @Test("Negative duration delta when right is faster")
    func durationDeltaNegative() {
        let differ = TraceDiffer()
        let a = session(name: "a", events: [], duration: 12)
        let b = session(name: "b", events: [], duration: 5)
        let result = differ.diff(left: a, right: b)
        #expect(result.durationDelta == -7)
    }

    @Test("Argv normalization preserves stable tokens")
    func normalizationStability() {
        let normalized = TraceDiffer.normalize(argv: ["clang", "-Wall", "-O2", "main.c"])
        #expect(normalized == ["clang", "-Wall", "-O2", "main.c"])
    }

    @Test("Argv normalization replaces /tmp paths")
    func normalizesTmpPaths() {
        let normalized = TraceDiffer.normalize(argv: ["mv", "/tmp/abc123/file.txt", "/var/folders/xy/zz/T/staged.bin"])
        #expect(normalized.contains { $0.contains("/tmp/<TMP>") })
        #expect(normalized.contains { $0.contains("/var/folders/<TMP>") })
    }

    @Test("totalChanges sums added + removed")
    func totalChanges() {
        let differ = TraceDiffer()
        let a = session(name: "a", events: [exec(parent: "p", child: "old", args: ["old"])])
        let b = session(name: "b", events: [exec(parent: "p", child: "new", args: ["new"])])
        let result = differ.diff(left: a, right: b)
        #expect(result.totalChanges == 2)
    }
}
