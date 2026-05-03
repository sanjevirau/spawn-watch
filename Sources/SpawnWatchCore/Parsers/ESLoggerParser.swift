import Foundation

public struct ESLoggerParser: Sendable {
    private let resolver = BundleResolver()

    public init() {}

    public func parse(line: String) -> SpawnEvent? {
        guard let data = line.data(using: .utf8) else { return nil }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let eventTypeStr = json["event_type"] as? String ?? ""
        let eventType: EventType
        if eventTypeStr.contains("EXEC") {
            eventType = .exec
        } else if eventTypeStr.contains("FORK") {
            eventType = .fork
        } else if eventTypeStr.contains("EXIT") {
            eventType = .exit
        } else {
            return nil
        }

        guard let eventDict = json["event"] as? [String: Any] else { return nil }
        let processDict = json["process"] as? [String: Any]

        var parent = extractIdentity(from: processDict)

        let child: ProcessIdentity
        var commandLine: [String]?
        var workingDirectory: String?
        var exitCode: Int32?
        var terminatingSignal: Int32?

        if eventType == .exec, let execDict = eventDict["exec"] as? [String: Any] {
            let targetDict = execDict["target"] as? [String: Any]
            child = extractIdentity(from: targetDict)

            if let args = execDict["args"] as? [String] {
                commandLine = args
            } else if let argsDict = execDict["args"] as? [[String: Any]] {
                commandLine = argsDict.compactMap { $0["string_arg"] as? String ?? $0["value"] as? String }
            }

            if let cwdDict = execDict["cwd"] as? [String: Any] {
                workingDirectory = cwdDict["path"] as? String
            } else if let targetDict = execDict["target"] as? [String: Any],
                      let cwdDict = targetDict["cwd"] as? [String: Any] {
                workingDirectory = cwdDict["path"] as? String
            }
        } else if eventType == .fork, let forkDict = eventDict["fork"] as? [String: Any] {
            let childDict = forkDict["child"] as? [String: Any]
            child = extractIdentity(from: childDict)
        } else if eventType == .exit, let exitDict = eventDict["exit"] as? [String: Any] {
            // For exit events, the dying process is in `process` — there's no separate child.
            // We model exit as parent → self so consumers can find the record by child PID.
            child = parent
            let stat = (exitDict["stat"] as? Int) ?? 0
            // BSD wstatus decoding: low 7 bits = signal, bit 7 = core dump, high 8 bits = exit code
            let signal = Int32(stat & 0x7F)
            let exited = signal == 0
            if exited {
                exitCode = Int32((stat >> 8) & 0xFF)
            } else {
                terminatingSignal = signal
            }
        } else {
            return nil
        }

        let childPath = child.executablePath
        let owningApp = resolver.resolveApp(fromExecutablePath: childPath)
            ?? resolver.resolveApp(fromExecutablePath: parent.executablePath)
        let relationship = resolver.resolveRelationship(executablePath: childPath)

        if parent.name == "unknown" || parent.pid <= 1, let app = owningApp {
            parent = ProcessIdentity(
                pid: parent.pid,
                name: app.name,
                executablePath: app.bundlePath + "/Contents/MacOS/" + app.name,
                bundleName: app.bundleIdentifier,
                spawnTime: parent.spawnTime
            )
        }

        return SpawnEvent(
            eventType: eventType,
            parent: parent,
            child: child,
            commandLine: commandLine,
            workingDirectory: workingDirectory,
            source: .eslogger,
            owningApp: owningApp,
            relationship: relationship,
            exitCode: exitCode,
            terminatingSignal: terminatingSignal
        )
    }

    private func extractIdentity(from dict: [String: Any]?) -> ProcessIdentity {
        guard let dict else {
            return ProcessIdentity(pid: -1, name: "unknown")
        }

        let pid: Int32
        if let auditToken = dict["audit_token"] as? [String: Any],
           let p = auditToken["pid"] as? Int {
            pid = Int32(p)
        } else if let p = dict["pid"] as? Int {
            pid = Int32(p)
        } else if let p = dict["ppid"] as? Int {
            pid = Int32(p)
        } else {
            pid = -1
        }

        var name = "unknown"
        if let execDict = dict["executable"] as? [String: Any],
           let path = execDict["path"] as? String {
            name = (path as NSString).lastPathComponent
        } else if let n = dict["name"] as? String {
            name = n
        }

        let execPath: String?
        if let execDict = dict["executable"] as? [String: Any] {
            execPath = execDict["path"] as? String
        } else {
            execPath = nil
        }

        let signingId = dict["signing_id"] as? String
        let bundleName: String?
        if let sigId = signingId, sigId.contains(".") {
            bundleName = sigId
        } else {
            bundleName = nil
        }

        // Try to extract the spawn time from start_time if eslogger provides it.
        // eslogger emits start_time either as a struct {tv_sec, tv_nsec} or as an ISO-8601 string.
        var spawnTime: Date? = nil
        if let startTime = dict["start_time"] as? [String: Any] {
            if let secs = startTime["tv_sec"] as? Int, let nsecs = startTime["tv_nsec"] as? Int {
                spawnTime = Date(timeIntervalSince1970: Double(secs) + Double(nsecs) / 1e9)
            } else if let iso = startTime["iso8601"] as? String {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                spawnTime = formatter.date(from: iso)
            }
        } else if let iso = dict["start_time"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            spawnTime = formatter.date(from: iso)
        }

        return ProcessIdentity(
            pid: pid,
            name: name,
            executablePath: execPath,
            bundleName: bundleName,
            spawnTime: spawnTime
        )
    }
}
