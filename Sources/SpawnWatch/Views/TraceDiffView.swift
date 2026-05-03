import SwiftUI
import SpawnWatchCore

struct TraceDiffView: View {
    let left: TraceSession
    let right: TraceSession
    let onClose: () -> Void

    @State private var result: TraceDiffResult?
    @State private var collapseUnchanged: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let result {
                summaryBar(result)
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        DiffBucket(title: "Added in \(right.name)", entries: result.added, accent: .green, icon: "plus.circle.fill")
                        DiffBucket(title: "Removed in \(right.name)", entries: result.removed, accent: .red, icon: "minus.circle.fill")
                        UnchangedBucket(entries: result.unchanged, collapsed: $collapseUnchanged)
                    }
                    .padding(18)
                }
            } else {
                ProgressView("Computing diff…").frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 1100, minHeight: 700)
        .onAppear {
            let differ = TraceDiffer()
            self.result = differ.diff(left: left, right: right)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.left.arrow.right.circle.fill")
                .font(.title2)
                .foregroundStyle(.indigo)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(left.name)  ⇄  \(right.name)")
                    .font(.title3.bold())
                Text("Comparing two trace sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
    }

    @ViewBuilder
    private func summaryBar(_ res: TraceDiffResult) -> some View {
        HStack(spacing: 22) {
            StatTile2("Added", value: "\(res.added.count)", tint: .green)
            StatTile2("Removed", value: "\(res.removed.count)", tint: .red)
            StatTile2("Unchanged", value: "\(res.unchanged.count)", tint: .secondary)
            StatTile2(
                "Δ Duration",
                value: durationDeltaLabel(res.durationDelta),
                tint: res.durationDelta > 0 ? .orange : .green
            )
            StatTile2("Events A", value: "\(res.leftCount)", tint: .blue)
            StatTile2("Events B", value: "\(res.rightCount)", tint: .indigo)
            Spacer()
        }
        .padding(.horizontal, 18).padding(.vertical, 8)
        .background(Color.secondary.opacity(0.06))
    }

    private func durationDeltaLabel(_ delta: TimeInterval) -> String {
        let sign = delta >= 0 ? "+" : "−"
        return "\(sign)\(Format.duration(abs(delta)))"
    }
}

private struct DiffBucket: View {
    let title: String
    let entries: [TraceDiffEntry]
    let accent: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundStyle(accent)
                Text(title).font(.headline)
                Text("(\(entries.count))").font(.subheadline).foregroundStyle(.secondary)
            }
            if entries.isEmpty {
                Text("None")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 24)
            } else {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(entries) { entry in
                        DiffEntryRow(entry: entry, accent: accent)
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(accent.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(accent.opacity(0.18), lineWidth: 0.5))
    }
}

private struct UnchangedBucket: View {
    let entries: [TraceDiffEntry]
    @Binding var collapsed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "equal.circle.fill").foregroundStyle(.secondary)
                Text("Unchanged").font(.headline)
                Text("(\(entries.count))").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                Button {
                    collapsed.toggle()
                } label: {
                    Image(systemName: collapsed ? "chevron.down.circle" : "chevron.up.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            if !collapsed {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(entries) { entry in
                        DiffEntryRow(entry: entry, accent: .secondary)
                    }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.secondary.opacity(0.18), lineWidth: 0.5))
    }
}

private struct DiffEntryRow: View {
    let entry: TraceDiffEntry
    let accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("×\(entry.occurrences)")
                .font(.system(.caption, design: .monospaced, weight: .bold))
                .frame(width: 36, alignment: .trailing)
                .foregroundStyle(accent)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.parentName).foregroundStyle(.secondary)
                    Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.tertiary)
                    Text(entry.childName).fontWeight(.medium)
                    if entry.exitFailures > 0 {
                        Image(systemName: "exclamationmark.triangle.fill").font(.caption2).foregroundStyle(.orange)
                        Text("\(entry.exitFailures) failure\(entry.exitFailures == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                if !entry.displayArgv.isEmpty {
                    Text(entry.displayArgv)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
            }

            Spacer()

            if entry.totalDuration > 0 {
                Text(Format.duration(entry.totalDuration))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct StatTile2: View {
    let label: String
    let value: String
    let tint: Color
    init(_ label: String, value: String, tint: Color) {
        self.label = label; self.value = value; self.tint = tint
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(.caption2, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.4)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(tint)
        }
    }
}
