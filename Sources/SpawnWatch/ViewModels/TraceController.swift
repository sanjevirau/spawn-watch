import Foundation
import SwiftUI
import SpawnWatchCore

@MainActor
@Observable
final class TraceController {
    private(set) var currentTrace: TraceSession?
    private(set) var savedSessions: [TraceSession] = []
    var isLoadingSessions: Bool = false
    var lastError: String?

    private let store: TraceStore
    private weak var eventStore: SpawnEventStore?

    init(store: TraceStore = TraceStore()) {
        self.store = store
    }

    func bind(eventStore: SpawnEventStore) {
        self.eventStore = eventStore
        eventStore.setTraceController(self)
    }

    var isRecording: Bool { currentTrace != nil }

    func startTrace(name: String? = nil) {
        guard !isRecording else { return }
        let id = UUID()
        let resolvedName = (name?.isEmpty == false ? name : nil)
            ?? defaultName(at: Date())
        var session = TraceSession(id: id, name: resolvedName!, startTime: Date(), endTime: nil, events: [], processes: [])
        session.events.reserveCapacity(2048)
        currentTrace = session
    }

    func stopTrace() {
        guard var session = currentTrace else { return }
        session.endTime = Date()

        // Snapshot processes touched in this trace.
        if let store = eventStore {
            var seen: Set<ProcessKey> = []
            for event in session.events {
                seen.insert(event.parentKey)
                seen.insert(event.childKey)
            }
            session.processes = seen.compactMap { store.record(for: $0)?.snapshot() }
        }

        currentTrace = nil

        Task { [store, session] in
            do {
                try await store.save(session)
                await MainActor.run {
                    self.savedSessions.insert(session, at: 0)
                }
            } catch {
                await MainActor.run {
                    self.lastError = "Failed to save trace: \(error.localizedDescription)"
                }
            }
        }
    }

    func appendIfRecording(_ event: SpawnEvent) {
        guard currentTrace != nil else { return }
        currentTrace?.events.append(event)
    }

    func loadSavedSessions() {
        isLoadingSessions = true
        Task { [store] in
            let loaded = (try? await store.list()) ?? []
            await MainActor.run {
                self.savedSessions = loaded.sorted { $0.startTime > $1.startTime }
                self.isLoadingSessions = false
            }
        }
    }

    func delete(_ session: TraceSession) {
        Task { [store, sessionId = session.id] in
            try? await store.delete(id: sessionId)
            await MainActor.run {
                self.savedSessions.removeAll { $0.id == sessionId }
            }
        }
    }

    func rename(_ session: TraceSession, to newName: String) {
        guard !newName.isEmpty else { return }
        var updated = session
        updated.name = newName
        Task { [store, updated] in
            try? await store.save(updated)
            await MainActor.run {
                if let idx = self.savedSessions.firstIndex(where: { $0.id == updated.id }) {
                    self.savedSessions[idx] = updated
                }
            }
        }
    }

    private func defaultName(at date: Date) -> String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d 'at' h:mm:ss a"
        return "Trace · \(formatter.string(from: date))"
    }
}
