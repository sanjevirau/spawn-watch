import Foundation

public final class PollingMonitor: SpawnMonitor, @unchecked Sendable {
    public let requiresRoot = false
    public let displayName = "Polling (libproc)"

    private let query = ProcessInfoQuery()
    private let resolver = BundleResolver()
    private let interval: Duration
    private var running = false

    public init(interval: Duration = .milliseconds(250)) {
        self.interval = interval
    }

    public func start() -> AsyncStream<SpawnEvent> {
        running = true

        return AsyncStream { continuation in
            let task = Task { [weak self] in
                guard let self else { return }

                var knownPids = Set(self.query.listAllPids())
                var pidIdentities: [Int32: ProcessIdentity] = [:]
                let now = Date()
                for pid in knownPids {
                    if let id = self.query.getProcessIdentity(pid: pid) {
                        pidIdentities[pid] = ProcessIdentity(
                            pid: id.pid,
                            name: id.name,
                            executablePath: id.executablePath,
                            bundleName: id.bundleName,
                            spawnTime: now
                        )
                    }
                }

                while self.running && !Task.isCancelled {
                    try? await Task.sleep(for: self.interval)
                    guard self.running else { break }

                    let currentPids = Set(self.query.listAllPids())
                    let newPids = currentPids.subtracting(knownPids)
                    let deadPids = knownPids.subtracting(currentPids)
                    let spawnTime = Date()

                    // Spawns
                    for pid in newPids {
                        guard let raw = self.query.getProcessIdentity(pid: pid) else { continue }
                        let child = ProcessIdentity(
                            pid: raw.pid,
                            name: raw.name,
                            executablePath: raw.executablePath,
                            bundleName: raw.bundleName,
                            spawnTime: spawnTime
                        )

                        let ppid = self.query.getParentPid(pid: pid) ?? 1
                        let parentRaw = self.query.getProcessIdentity(pid: ppid)
                            ?? ProcessIdentity(pid: ppid, name: "unknown")
                        let parent = ProcessIdentity(
                            pid: parentRaw.pid,
                            name: parentRaw.name,
                            executablePath: parentRaw.executablePath,
                            bundleName: parentRaw.bundleName,
                            spawnTime: pidIdentities[ppid]?.spawnTime
                        )

                        let args = self.query.getCommandLineArgs(pid: pid)

                        let childPath = child.executablePath
                        let owningApp = self.resolver.resolveApp(fromExecutablePath: childPath)
                            ?? self.resolver.resolveApp(fromExecutablePath: parent.executablePath)
                        let relationship = self.resolver.resolveRelationship(executablePath: childPath)

                        let enrichedParent: ProcessIdentity
                        if parent.name == "unknown" || parent.pid == 1, let app = owningApp {
                            enrichedParent = ProcessIdentity(
                                pid: parent.pid,
                                name: app.name,
                                executablePath: app.bundlePath + "/Contents/MacOS/" + app.name,
                                bundleName: app.bundleIdentifier,
                                spawnTime: parent.spawnTime
                            )
                        } else {
                            enrichedParent = parent
                        }

                        let enrichedChild = ProcessIdentity(
                            pid: child.pid,
                            name: child.name,
                            executablePath: child.executablePath,
                            bundleName: owningApp?.bundleIdentifier ?? child.bundleName,
                            spawnTime: child.spawnTime
                        )

                        pidIdentities[pid] = enrichedChild

                        let event = SpawnEvent(
                            eventType: .exec,
                            parent: enrichedParent,
                            child: enrichedChild,
                            commandLine: args,
                            source: .polling,
                            owningApp: owningApp,
                            relationship: relationship
                        )

                        continuation.yield(event)
                    }

                    // Exits — synthesized when a PID disappears between ticks.
                    // We can't know exit code from polling, so leave it nil.
                    for pid in deadPids {
                        guard let lastIdentity = pidIdentities[pid] else { continue }
                        let parent = ProcessIdentity(pid: 0, name: "kernel", spawnTime: nil)
                        let owningApp = self.resolver.resolveApp(fromExecutablePath: lastIdentity.executablePath)
                        let event = SpawnEvent(
                            eventType: .exit,
                            parent: parent,
                            child: lastIdentity,
                            source: .polling,
                            owningApp: owningApp,
                            relationship: self.resolver.resolveRelationship(executablePath: lastIdentity.executablePath)
                        )
                        continuation.yield(event)
                        pidIdentities.removeValue(forKey: pid)
                    }

                    knownPids = currentPids
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
    }
}
