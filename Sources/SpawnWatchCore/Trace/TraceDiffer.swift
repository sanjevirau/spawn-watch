import Foundation

public struct TraceDiffEntry: Identifiable, Hashable, Sendable {
    public let id: String
    public let parentName: String
    public let childName: String
    public let argv: [String]
    public let occurrences: Int
    public let totalDuration: TimeInterval
    public let exitFailures: Int

    public var displayArgv: String {
        argv.dropFirst().joined(separator: " ")
    }
}

public struct TraceDiffResult: Sendable {
    public let added: [TraceDiffEntry]
    public let removed: [TraceDiffEntry]
    public let unchanged: [TraceDiffEntry]
    public let durationDelta: TimeInterval
    public let leftCount: Int
    public let rightCount: Int

    public var totalChanges: Int { added.count + removed.count }
}

public struct TraceDiffer: Sendable {
    public init() {}

    public func diff(left: TraceSession, right: TraceSession) -> TraceDiffResult {
        let leftMap = bucket(left)
        let rightMap = bucket(right)

        let leftKeys = Set(leftMap.keys)
        let rightKeys = Set(rightMap.keys)

        let addedKeys = rightKeys.subtracting(leftKeys)
        let removedKeys = leftKeys.subtracting(rightKeys)
        let sharedKeys = leftKeys.intersection(rightKeys)

        let added = addedKeys.compactMap { rightMap[$0] }.sorted { $0.occurrences > $1.occurrences }
        let removed = removedKeys.compactMap { leftMap[$0] }.sorted { $0.occurrences > $1.occurrences }
        let unchanged = sharedKeys.compactMap { rightMap[$0] }.sorted { $0.occurrences > $1.occurrences }

        return TraceDiffResult(
            added: added,
            removed: removed,
            unchanged: unchanged,
            durationDelta: right.duration - left.duration,
            leftCount: left.events.count,
            rightCount: right.events.count
        )
    }

    private func bucket(_ session: TraceSession) -> [String: TraceDiffEntry] {
        var counts: [String: (entry: TraceDiffEntry, durations: TimeInterval, failures: Int)] = [:]
        let processByKey: [ProcessKey: ProcessSnapshot] = Dictionary(uniqueKeysWithValues: session.processes.map { ($0.key, $0) })

        for event in session.events where event.eventType == .exec {
            let parentName = event.parent.name
            let childName = event.child.name
            let argv = event.commandLine ?? []
            let normalized = Self.normalize(argv: argv)
            let key = "\(parentName)>>\(childName)>>\(normalized.joined(separator: " "))"

            let snapshot = processByKey[event.childKey]
            let duration = snapshot?.duration ?? 0
            let failed = ((snapshot?.exitCode ?? 0) != 0) || (snapshot?.wasKilled ?? false)

            if let existing = counts[key] {
                let entry = TraceDiffEntry(
                    id: key,
                    parentName: parentName,
                    childName: childName,
                    argv: existing.entry.argv,
                    occurrences: existing.entry.occurrences + 1,
                    totalDuration: existing.durations + duration,
                    exitFailures: existing.failures + (failed ? 1 : 0)
                )
                counts[key] = (entry, existing.durations + duration, existing.failures + (failed ? 1 : 0))
            } else {
                let entry = TraceDiffEntry(
                    id: key,
                    parentName: parentName,
                    childName: childName,
                    argv: normalized,
                    occurrences: 1,
                    totalDuration: duration,
                    exitFailures: failed ? 1 : 0
                )
                counts[key] = (entry, duration, failed ? 1 : 0)
            }
        }

        return counts.mapValues(\.entry)
    }

    public static func normalize(argv: [String]) -> [String] {
        argv.map { token in
            var t = token
            for pattern in patterns {
                if let regex = pattern.regex {
                    t = regex.stringByReplacingMatches(
                        in: t,
                        range: NSRange(t.startIndex..., in: t),
                        withTemplate: pattern.replacement
                    )
                }
            }
            return t
        }
    }

    private struct Pattern {
        let regex: NSRegularExpression?
        let replacement: String
        init(_ pattern: String, _ replacement: String) {
            self.regex = try? NSRegularExpression(pattern: pattern, options: [])
            self.replacement = replacement
        }
    }

    private static let patterns: [Pattern] = [
        Pattern(#"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z?"#, "<TS>"),
        Pattern(#"[a-fA-F0-9]{32,}"#, "<HEX>"),
        Pattern(#"/var/folders/[^\s'"]+"#, "/var/folders/<TMP>"),
        Pattern(#"/private/tmp/[^\s'"]+"#, "/private/tmp/<TMP>"),
        Pattern(#"/tmp/[^\s'"]+"#, "/tmp/<TMP>"),
        Pattern(#"\b\d{4,}\b"#, "<N>"),
    ]
}
