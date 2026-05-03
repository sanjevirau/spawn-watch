import Foundation

public struct ProcessKey: Hashable, Codable, Sendable, CustomStringConvertible {
    public let pid: Int32
    public let spawnTime: Date

    public init(pid: Int32, spawnTime: Date) {
        self.pid = pid
        self.spawnTime = Self.normalize(spawnTime)
    }

    private static func normalize(_ date: Date) -> Date {
        // Truncate (floor) to milliseconds so two timestamps within the same ms
        // hash identically and equality is independent of rounding mode.
        let millis = (date.timeIntervalSince1970 * 1000).rounded(.down)
        return Date(timeIntervalSince1970: millis / 1000)
    }

    public var description: String { "pid:\(pid)@\(Int(spawnTime.timeIntervalSince1970 * 1000))" }
}
