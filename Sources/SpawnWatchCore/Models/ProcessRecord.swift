import Foundation
import Observation

public enum TrustState: Sendable, Equatable {
    case unknown
    case pending
    case ready
    case failed(String)
}

@MainActor
@Observable
public final class ProcessRecord {
    public nonisolated let key: ProcessKey
    public var identity: ProcessIdentity
    public var parentKey: ProcessKey?
    public let spawnTime: Date
    public var exitTime: Date?
    public var exitCode: Int32?
    public var terminatingSignal: Int32?
    public var commandLine: [String]?
    public var workingDirectory: String?
    public var owningApp: AppBundleInfo?
    public var relationship: ProcessRelationship
    public var source: MonitorSource
    public var children: [ProcessKey] = []
    public var firstSeen: Date

    // Phase 2 (trust)
    public var trust: TrustInfo?
    public var trustState: TrustState = .unknown

    public init(
        key: ProcessKey,
        identity: ProcessIdentity,
        parentKey: ProcessKey?,
        spawnTime: Date,
        commandLine: [String]? = nil,
        workingDirectory: String? = nil,
        owningApp: AppBundleInfo? = nil,
        relationship: ProcessRelationship = .unknown,
        source: MonitorSource = .polling
    ) {
        self.key = key
        self.identity = identity
        self.parentKey = parentKey
        self.spawnTime = spawnTime
        self.commandLine = commandLine
        self.workingDirectory = workingDirectory
        self.owningApp = owningApp
        self.relationship = relationship
        self.source = source
        self.firstSeen = spawnTime
    }

    public var isAlive: Bool { exitTime == nil }
    public var duration: TimeInterval? { exitTime.map { $0.timeIntervalSince(spawnTime) } }
    public var wasKilled: Bool { (terminatingSignal ?? 0) != 0 }

    public func snapshot() -> ProcessSnapshot {
        ProcessSnapshot(
            key: key,
            identity: identity,
            parentKey: parentKey,
            spawnTime: spawnTime,
            exitTime: exitTime,
            exitCode: exitCode,
            terminatingSignal: terminatingSignal,
            commandLine: commandLine,
            workingDirectory: workingDirectory,
            owningApp: owningApp,
            relationship: relationship,
            source: source,
            children: children,
            trust: trust
        )
    }
}

extension ProcessRecord: Identifiable {
    public nonisolated var id: ProcessKey { key }
}

public struct ProcessSnapshot: Identifiable, Codable, Sendable, Hashable {
    public let key: ProcessKey
    public let identity: ProcessIdentity
    public let parentKey: ProcessKey?
    public let spawnTime: Date
    public let exitTime: Date?
    public let exitCode: Int32?
    public let terminatingSignal: Int32?
    public let commandLine: [String]?
    public let workingDirectory: String?
    public let owningApp: AppBundleInfo?
    public let relationship: ProcessRelationship
    public let source: MonitorSource
    public let children: [ProcessKey]
    public let trust: TrustInfo?

    public var id: ProcessKey { key }
    public var isAlive: Bool { exitTime == nil }
    public var duration: TimeInterval? { exitTime.map { $0.timeIntervalSince(spawnTime) } }
    public var wasKilled: Bool { (terminatingSignal ?? 0) != 0 }
}
