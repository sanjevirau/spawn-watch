import Foundation
import Testing
@testable import SpawnWatchCore

@Suite("TraceSession Tests")
struct TraceSessionTests {
    private func snapshot(
        pid: Int32,
        parent: Int32?,
        exitCode: Int32? = nil,
        signal: Int32? = nil,
        signing: SigningType = .apple,
        owningApp: AppBundleInfo? = nil
    ) -> ProcessSnapshot {
        let spawn = Date(timeIntervalSince1970: 1_700_000_000)
        let parentKey = parent.map { ProcessKey(pid: $0, spawnTime: spawn) }
        return ProcessSnapshot(
            key: ProcessKey(pid: pid, spawnTime: spawn),
            identity: ProcessIdentity(pid: pid, name: "p\(pid)"),
            parentKey: parentKey,
            spawnTime: spawn,
            exitTime: spawn.addingTimeInterval(0.5),
            exitCode: exitCode,
            terminatingSignal: signal,
            commandLine: nil,
            workingDirectory: nil,
            owningApp: owningApp,
            relationship: .unknown,
            source: .eslogger,
            children: [],
            trust: TrustInfo(signingType: signing)
        )
    }

    private func session(processes: [ProcessSnapshot]) -> TraceSession {
        TraceSession(
            id: UUID(),
            name: "test",
            startTime: Date(timeIntervalSince1970: 1_700_000_000),
            endTime: Date(timeIntervalSince1970: 1_700_000_010),
            events: [],
            processes: processes
        )
    }

    @Test("rootProcesses returns snapshots whose parent is missing from the set")
    func rootDetection() {
        let s = session(processes: [
            snapshot(pid: 100, parent: nil),
            snapshot(pid: 200, parent: 100),
            snapshot(pid: 300, parent: 999),  // parent not in set → also a root
        ])
        let roots = s.rootProcesses
        let rootPids = roots.map(\.identity.pid).sorted()
        #expect(rootPids == [100, 300])
    }

    @Test("children returns direct descendants")
    func childrenLookup() {
        let s = session(processes: [
            snapshot(pid: 100, parent: nil),
            snapshot(pid: 200, parent: 100),
            snapshot(pid: 201, parent: 100),
            snapshot(pid: 300, parent: 200),
        ])
        let kids = s.children(of: ProcessKey(pid: 100, spawnTime: Date(timeIntervalSince1970: 1_700_000_000)))
        #expect(kids.count == 2)
        #expect(Set(kids.map(\.identity.pid)) == Set([200, 201]))
    }

    @Test("failedCount counts non-zero exit and signaled processes")
    func failedCount() {
        let s = session(processes: [
            snapshot(pid: 100, parent: nil, exitCode: 0),
            snapshot(pid: 200, parent: nil, exitCode: 1),     // failed
            snapshot(pid: 300, parent: nil, signal: 9),       // killed
            snapshot(pid: 400, parent: nil, exitCode: 0),
        ])
        #expect(s.failedCount == 2)
    }

    @Test("unsignedCount counts unsigned + ad-hoc")
    func unsignedCount() {
        let s = session(processes: [
            snapshot(pid: 100, parent: nil, signing: .apple),
            snapshot(pid: 200, parent: nil, signing: .unsigned),
            snapshot(pid: 300, parent: nil, signing: .adhoc),
            snapshot(pid: 400, parent: nil, signing: .developerID),
        ])
        #expect(s.unsignedCount == 2)
    }

    @Test("uniqueAppNames is sorted, deduplicated, only includes apps")
    func uniqueAppNames() {
        let appA = AppBundleInfo(name: "Slack", bundlePath: "/Applications/Slack.app")
        let appB = AppBundleInfo(name: "Xcode", bundlePath: "/Applications/Xcode.app")
        let s = session(processes: [
            snapshot(pid: 100, parent: nil, owningApp: appB),
            snapshot(pid: 200, parent: nil, owningApp: appA),
            snapshot(pid: 300, parent: nil, owningApp: appA),
            snapshot(pid: 400, parent: nil, owningApp: nil),
        ])
        #expect(s.uniqueAppNames == ["Slack", "Xcode"])
    }

    @Test("duration uses endTime when provided")
    func durationWithEndTime() {
        let s = session(processes: [])
        #expect(s.duration == 10)
    }

    @Test("Codable round-trips a complete session")
    func codableRoundtrip() throws {
        let original = session(processes: [snapshot(pid: 100, parent: nil)])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TraceSession.self, from: data)
        #expect(decoded.id == original.id)
        #expect(decoded.processes.count == 1)
    }
}
