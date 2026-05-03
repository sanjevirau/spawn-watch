import Foundation
import SwiftUI
import SpawnWatchCore

@MainActor
@Observable
final class SpawnEventStore {
    var events: [SpawnEvent] = []
    var selectedEvent: SpawnEvent?
    var searchText: String = ""
    var isPaused: Bool = false
    var hideSystemNoise: Bool = true
    var monitorStatus: String = "Idle"
    var activeSource: String = "polling"
    var eventCount: Int = 0

    var processes: [ProcessKey: ProcessRecord] = [:]
    var rootKeys: [ProcessKey] = []
    var trustVersion: Int = 0

    private let maxEvents = 10_000
    private let maxRecords = 20_000
    private let resolver = BundleResolver()
    private let inspector: SigningInspector
    private var monitor: CompositeMonitor?
    private var monitorTask: Task<Void, Never>?
    private var pausedBuffer: [SpawnEvent] = []
    private var pidToLatestKey: [Int32: ProcessKey] = [:]
    weak var traceController: TraceController?

    init(inspector: SigningInspector = .shared) {
        self.inspector = inspector
    }

    var filteredEvents: [SpawnEvent] {
        var result = events

        if hideSystemNoise {
            result = result.filter { !resolver.isSystemNoise($0.child.executablePath) }
        }

        guard !searchText.isEmpty else { return result }
        let query = searchText.lowercased()
        return result.filter { event in
            event.child.name.lowercased().contains(query)
            || event.parent.name.lowercased().contains(query)
            || (event.child.executablePath?.lowercased().contains(query) ?? false)
            || (event.commandLine?.joined(separator: " ").lowercased().contains(query) ?? false)
            || (event.owningApp?.name.lowercased().contains(query) ?? false)
            || (event.owningApp?.bundleIdentifier?.lowercased().contains(query) ?? false)
            || event.relationship.rawValue.lowercased().contains(query)
        }
    }

    var appGroups: [String: [SpawnEvent]] {
        var groups: [String: [SpawnEvent]] = [:]
        for event in filteredEvents {
            let key = event.owningApp?.name ?? "System / Other"
            groups[key, default: []].append(event)
        }
        return groups
    }

    var rootRecords: [ProcessRecord] {
        rootKeys.compactMap { processes[$0] }
    }

    func record(for key: ProcessKey) -> ProcessRecord? { processes[key] }

    func children(of key: ProcessKey) -> [ProcessRecord] {
        guard let record = processes[key] else { return [] }
        return record.children.compactMap { processes[$0] }
    }

    func lineage(for key: ProcessKey) -> [ProcessRecord] {
        var chain: [ProcessRecord] = []
        var current: ProcessKey? = key
        var depth = 0
        while let k = current, let record = processes[k], depth < 32 {
            chain.append(record)
            current = record.parentKey
            depth += 1
        }
        return chain
    }

    func startMonitoring() {
        guard monitorTask == nil else { return }

        let composite = CompositeMonitor()
        monitor = composite
        monitorStatus = "Starting…"

        let stream = composite.start()
        monitorTask = Task { [weak self] in
            for await event in stream {
                guard let self else { break }
                let source = composite.activeSource
                self.monitorStatus = source == .eslogger ? "eslogger (real-time)" : "Polling (libproc)"
                self.activeSource = source.rawValue

                if self.isPaused {
                    self.pausedBuffer.append(event)
                    if self.pausedBuffer.count > self.maxEvents {
                        self.pausedBuffer.removeFirst(self.pausedBuffer.count - self.maxEvents)
                    }
                    continue
                }

                self.ingest(event)
            }
        }
    }

    func stopMonitoring() {
        monitor?.stop()
        monitorTask?.cancel()
        monitorTask = nil
        monitor = nil
        monitorStatus = "Stopped"
    }

    func clearEvents() {
        events.removeAll()
        processes.removeAll()
        rootKeys.removeAll()
        pidToLatestKey.removeAll()
        eventCount = 0
    }

    func togglePause() {
        isPaused.toggle()
        if !isPaused {
            let drained = pausedBuffer
            pausedBuffer.removeAll()
            for event in drained { ingest(event) }
        }
    }

    func ingest(_ event: SpawnEvent) {
        events.insert(event, at: 0)
        eventCount += 1
        if events.count > maxEvents {
            events.removeLast(events.count - maxEvents)
        }

        switch event.eventType {
        case .fork:
            handleFork(event)
        case .exec:
            handleExec(event)
        case .exit:
            handleExit(event)
        }

        traceController?.appendIfRecording(event)
        evictIfNeeded()
    }

    private func handleFork(_ event: SpawnEvent) {
        let parentRecord = upsertParent(event)
        let childKey = event.childKey
        if processes[childKey] == nil {
            let record = ProcessRecord(
                key: childKey,
                identity: event.child,
                parentKey: parentRecord?.key,
                spawnTime: event.child.spawnTime ?? event.timestamp,
                workingDirectory: event.workingDirectory,
                owningApp: event.owningApp,
                relationship: event.relationship,
                source: event.source
            )
            processes[childKey] = record
            pidToLatestKey[childKey.pid] = childKey
            attachToParent(record)
            scheduleTrustLookup(for: record)
        }
    }

    private func handleExec(_ event: SpawnEvent) {
        let parentRecord = upsertParent(event)
        let childKey = event.childKey

        if let existing = processes[childKey] {
            existing.identity = event.child
            existing.commandLine = event.commandLine
            existing.workingDirectory = event.workingDirectory ?? existing.workingDirectory
            existing.owningApp = event.owningApp ?? existing.owningApp
            existing.relationship = event.relationship
            existing.source = event.source
            scheduleTrustLookup(for: existing)
            return
        }

        // Different spawnTime (re-exec into a new program with a new identity in our model)
        let record = ProcessRecord(
            key: childKey,
            identity: event.child,
            parentKey: parentRecord?.key,
            spawnTime: event.child.spawnTime ?? event.timestamp,
            commandLine: event.commandLine,
            workingDirectory: event.workingDirectory,
            owningApp: event.owningApp,
            relationship: event.relationship,
            source: event.source
        )
        processes[childKey] = record
        pidToLatestKey[childKey.pid] = childKey
        attachToParent(record)
        scheduleTrustLookup(for: record)
    }

    private func handleExit(_ event: SpawnEvent) {
        let key: ProcessKey
        if let known = pidToLatestKey[event.child.pid] {
            key = known
        } else {
            key = event.childKey
        }
        guard let record = processes[key] else { return }
        record.exitTime = event.timestamp
        record.exitCode = event.exitCode
        record.terminatingSignal = event.terminatingSignal
        pidToLatestKey.removeValue(forKey: key.pid)
    }

    @discardableResult
    private func upsertParent(_ event: SpawnEvent) -> ProcessRecord? {
        let parentPid = event.parent.pid
        guard parentPid > 0 else { return nil }

        if let knownKey = pidToLatestKey[parentPid], let existing = processes[knownKey] {
            return existing
        }

        let parentKey = event.parentKey
        if let existing = processes[parentKey] { return existing }

        let synthesized = ProcessRecord(
            key: parentKey,
            identity: event.parent,
            parentKey: nil,
            spawnTime: event.parent.spawnTime ?? event.timestamp,
            owningApp: event.owningApp,
            relationship: event.relationship,
            source: event.source
        )
        processes[parentKey] = synthesized
        pidToLatestKey[parentKey.pid] = parentKey
        if !rootKeys.contains(parentKey) { rootKeys.append(parentKey) }
        scheduleTrustLookup(for: synthesized)
        return synthesized
    }

    private func attachToParent(_ record: ProcessRecord) {
        if let parentKey = record.parentKey, let parent = processes[parentKey] {
            if !parent.children.contains(record.key) {
                parent.children.append(record.key)
            }
        } else {
            if !rootKeys.contains(record.key) { rootKeys.append(record.key) }
        }
    }

    private func evictIfNeeded() {
        guard processes.count > maxRecords else { return }
        let evictCount = processes.count - maxRecords
        let candidates = processes.values
            .filter { !$0.isAlive }
            .sorted { ($0.exitTime ?? .distantPast) < ($1.exitTime ?? .distantPast) }
            .prefix(evictCount)
        for record in candidates {
            if let parentKey = record.parentKey, let parent = processes[parentKey] {
                parent.children.removeAll { $0 == record.key }
            }
            rootKeys.removeAll { $0 == record.key }
            processes.removeValue(forKey: record.key)
        }
    }

    private func scheduleTrustLookup(for record: ProcessRecord) {
        guard let path = record.identity.executablePath else { return }
        guard record.trustState == .unknown || record.trustState == .pending else { return }
        guard record.trust == nil else { return }
        record.trustState = .pending
        let key = record.key

        Task.detached { [inspector] in
            let info = await inspector.info(for: path)
            await MainActor.run {
                guard let r = self.processes[key] else { return }
                r.trust = info
                r.trustState = info.signingType == .unknown ? .failed("Inspection failed") : .ready
                self.trustVersion &+= 1
            }
        }
    }

    func setTraceController(_ controller: TraceController) {
        self.traceController = controller
    }
}
