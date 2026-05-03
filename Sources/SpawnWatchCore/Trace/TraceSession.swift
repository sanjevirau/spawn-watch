import Foundation

public struct TraceSession: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var name: String
    public let startTime: Date
    public var endTime: Date?
    public var events: [SpawnEvent]
    public var processes: [ProcessSnapshot]

    public init(
        id: UUID = UUID(),
        name: String,
        startTime: Date,
        endTime: Date? = nil,
        events: [SpawnEvent] = [],
        processes: [ProcessSnapshot] = []
    ) {
        self.id = id
        self.name = name
        self.startTime = startTime
        self.endTime = endTime
        self.events = events
        self.processes = processes
    }

    public var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }

    public var rootProcesses: [ProcessSnapshot] {
        let allKeys = Set(processes.map(\.key))
        return processes.filter { snapshot in
            guard let parent = snapshot.parentKey else { return true }
            return !allKeys.contains(parent)
        }
    }

    public func record(for key: ProcessKey) -> ProcessSnapshot? {
        processes.first(where: { $0.key == key })
    }

    public func children(of key: ProcessKey) -> [ProcessSnapshot] {
        processes.filter { $0.parentKey == key }
    }

    public var uniqueAppNames: [String] {
        var names = Set<String>()
        for snap in processes {
            if let app = snap.owningApp?.name { names.insert(app) }
        }
        return names.sorted()
    }

    public var failedCount: Int {
        processes.filter { snap in
            (snap.exitCode != nil && snap.exitCode != 0) || snap.wasKilled
        }.count
    }

    public var unsignedCount: Int {
        processes.filter {
            ($0.trust?.signingType == .unsigned) || ($0.trust?.signingType == .adhoc)
        }.count
    }
}
