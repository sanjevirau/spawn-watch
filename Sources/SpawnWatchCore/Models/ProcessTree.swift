import Foundation

public final class ProcessTreeNode: Identifiable, @unchecked Sendable {
    public let id: ProcessKey
    public let identity: ProcessIdentity
    public let spawnTime: Date?
    public weak var parent: ProcessTreeNode?
    public var children: [ProcessTreeNode] = []
    public var eventCount: Int = 0

    public init(identity: ProcessIdentity, spawnTime: Date? = nil) {
        self.id = ProcessKey(pid: identity.pid, spawnTime: spawnTime ?? identity.spawnTime ?? Date())
        self.identity = identity
        self.spawnTime = spawnTime
    }
}
