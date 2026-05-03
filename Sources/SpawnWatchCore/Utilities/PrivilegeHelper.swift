import Foundation

public struct PrivilegeHelper: Sendable {
    public init() {}

    public func launchPrivilegedESLogger() throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-e",
            #"do shell script "/usr/bin/eslogger exec fork exit --format json" with administrator privileges"#,
        ]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        return process
    }
}
