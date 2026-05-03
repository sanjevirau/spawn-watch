import Foundation

public final class CompositeMonitor: SpawnMonitor, @unchecked Sendable {
    public let requiresRoot = false
    public let displayName = "Composite"

    private let esloggerMonitor = ESLoggerMonitor()
    private let pollingMonitor = PollingMonitor()
    private var running = false
    private let dedupeWindow: TimeInterval = 0.5

    public private(set) var activeSource: MonitorSource = .polling

    public init() {}

    public func start() -> AsyncStream<SpawnEvent> {
        running = true

        return AsyncStream { continuation in
            let dedupe = DedupeBox(window: dedupeWindow)

            let task = Task { [self] in
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        let stream = self.esloggerMonitor.start()
                        var receivedFirst = false
                        for await event in stream {
                            if !receivedFirst {
                                receivedFirst = true
                                await MainActor.run { self.activeSource = .eslogger }
                            }
                            if await dedupe.shouldEmit(event) {
                                continuation.yield(event)
                            }
                        }
                    }

                    group.addTask {
                        try? await Task.sleep(for: .seconds(2))
                        guard self.running else { return }

                        let stream = self.pollingMonitor.start()
                        for await event in stream {
                            if await dedupe.shouldEmit(event) {
                                continuation.yield(event)
                            }
                        }
                    }

                    await group.waitForAll()
                }

                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    public func stop() {
        running = false
        esloggerMonitor.stop()
        pollingMonitor.stop()
    }
}

public actor DedupeBox {
    struct Key: Hashable {
        let pid: Int32
        let type: EventType
    }

    private var seen: [Key: Date] = [:]
    private let window: TimeInterval

    public init(window: TimeInterval) {
        self.window = window
    }

    public func shouldEmit(_ event: SpawnEvent) -> Bool {
        let key = Key(pid: event.child.pid, type: event.eventType)
        let now = Date()
        if let last = seen[key], now.timeIntervalSince(last) < window {
            return false
        }
        seen[key] = now
        if seen.count > 8192 {
            let cutoff = now.addingTimeInterval(-window * 4)
            seen = seen.filter { $0.value > cutoff }
        }
        return true
    }
}
