import Foundation

public protocol SpawnMonitor: Sendable {
    func start() -> AsyncStream<SpawnEvent>
    func stop()
    var requiresRoot: Bool { get }
    var displayName: String { get }
}
