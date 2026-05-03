import Foundation

public enum EventType: String, Codable, Sendable {
    case exec
    case fork
    case exit
}

public enum MonitorSource: String, Codable, Sendable {
    case eslogger
    case polling
}

public enum ProcessRelationship: String, Codable, Sendable {
    case xpcService = "XPC Service"
    case appExtension = "App Extension"
    case helper = "Helper"
    case framework = "Framework Service"
    case directChild = "Direct Child"
    case system = "System"
    case unknown = "Unknown"
}

public struct SpawnEvent: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let eventType: EventType
    public let parent: ProcessIdentity
    public let child: ProcessIdentity
    public let commandLine: [String]?
    public let workingDirectory: String?
    public let source: MonitorSource
    public let owningApp: AppBundleInfo?
    public let relationship: ProcessRelationship
    public let exitCode: Int32?
    public let terminatingSignal: Int32?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        eventType: EventType,
        parent: ProcessIdentity,
        child: ProcessIdentity,
        commandLine: [String]? = nil,
        workingDirectory: String? = nil,
        source: MonitorSource,
        owningApp: AppBundleInfo? = nil,
        relationship: ProcessRelationship = .unknown,
        exitCode: Int32? = nil,
        terminatingSignal: Int32? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.eventType = eventType
        self.parent = parent
        self.child = child
        self.commandLine = commandLine
        self.workingDirectory = workingDirectory
        self.source = source
        self.owningApp = owningApp
        self.relationship = relationship
        self.exitCode = exitCode
        self.terminatingSignal = terminatingSignal
    }

    public var parentKey: ProcessKey {
        ProcessKey(pid: parent.pid, spawnTime: parent.spawnTime ?? timestamp)
    }

    public var childKey: ProcessKey {
        ProcessKey(pid: child.pid, spawnTime: child.spawnTime ?? timestamp)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.timestamp = try c.decode(Date.self, forKey: .timestamp)
        self.eventType = try c.decode(EventType.self, forKey: .eventType)
        self.parent = try c.decode(ProcessIdentity.self, forKey: .parent)
        self.child = try c.decode(ProcessIdentity.self, forKey: .child)
        self.commandLine = try c.decodeIfPresent([String].self, forKey: .commandLine)
        self.workingDirectory = try c.decodeIfPresent(String.self, forKey: .workingDirectory)
        self.source = try c.decode(MonitorSource.self, forKey: .source)
        self.owningApp = try c.decodeIfPresent(AppBundleInfo.self, forKey: .owningApp)
        self.relationship = try c.decodeIfPresent(ProcessRelationship.self, forKey: .relationship) ?? .unknown
        self.exitCode = try c.decodeIfPresent(Int32.self, forKey: .exitCode)
        self.terminatingSignal = try c.decodeIfPresent(Int32.self, forKey: .terminatingSignal)
    }

    private enum CodingKeys: String, CodingKey {
        case id, timestamp, eventType, parent, child, commandLine, workingDirectory
        case source, owningApp, relationship, exitCode, terminatingSignal
    }
}

public struct AppBundleInfo: Hashable, Codable, Sendable {
    public let name: String
    public let bundlePath: String
    public let bundleIdentifier: String?

    public init(name: String, bundlePath: String, bundleIdentifier: String? = nil) {
        self.name = name
        self.bundlePath = bundlePath
        self.bundleIdentifier = bundleIdentifier
    }
}
