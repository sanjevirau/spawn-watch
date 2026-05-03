import Foundation

public final class ESLoggerMonitor: SpawnMonitor, @unchecked Sendable {
    public let requiresRoot = true
    public let displayName = "eslogger (real-time)"

    private let parser = ESLoggerParser()
    private let privilegeHelper = PrivilegeHelper()
    private var process: Process?
    private var running = false

    public init() {}

    public func start() -> AsyncStream<SpawnEvent> {
        running = true

        return AsyncStream { continuation in
            let task = Task.detached { [self] in
                do {
                    let proc = try self.privilegeHelper.launchPrivilegedESLogger()
                    self.process = proc

                    guard let stdout = proc.standardOutput as? Pipe else {
                        continuation.finish()
                        return
                    }

                    let handle = stdout.fileHandleForReading

                    var buffer = Data()
                    let newline = UInt8(ascii: "\n")

                    while self.running && proc.isRunning && !Task.isCancelled {
                        let available = handle.availableData
                        guard !available.isEmpty else {
                            if !proc.isRunning { break }
                            try await Task.sleep(for: .milliseconds(10))
                            continue
                        }

                        buffer.append(available)

                        while let newlineIndex = buffer.firstIndex(of: newline) {
                            let lineData = buffer[buffer.startIndex..<newlineIndex]
                            buffer = Data(buffer[buffer.index(after: newlineIndex)...])

                            if let line = String(data: lineData, encoding: .utf8),
                               !line.isEmpty,
                               let event = self.parser.parse(line: line) {
                                continuation.yield(event)
                            }
                        }
                    }
                } catch {
                    // eslogger launch failed (user cancelled auth dialog, etc.)
                }

                continuation.finish()
            }

            continuation.onTermination = { [weak self] _ in
                task.cancel()
                self?.stop()
            }
        }
    }

    public func stop() {
        running = false
        process?.terminate()
        process = nil
    }
}
