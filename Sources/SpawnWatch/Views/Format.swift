import Foundation

enum Format {
    static func duration(_ interval: TimeInterval) -> String {
        if interval < 0.001 { return "<1ms" }
        if interval < 1 { return String(format: "%.0fms", interval * 1000) }
        if interval < 10 { return String(format: "%.2fs", interval) }
        if interval < 60 { return String(format: "%.1fs", interval) }
        if interval < 3600 {
            let minutes = Int(interval) / 60
            let seconds = Int(interval) % 60
            return "\(minutes)m \(seconds)s"
        }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    static func relative(from date: Date, to other: Date = Date()) -> String {
        duration(other.timeIntervalSince(date))
    }

    static func bytes(_ value: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(value))
    }
}
