import SwiftUI
import SpawnWatchCore

struct ProcessTreeView: View {
    @Environment(SpawnEventStore.self) private var store
    let roots: [ProcessRecord]
    @Binding var selectedKey: ProcessKey?

    var body: some View {
        List(selection: $selectedKey) {
            ForEach(roots, id: \.key) { root in
                ProcessOutlineNode(record: root)
                    .environment(store)
            }
        }
        .listStyle(.sidebar)
    }
}

private struct ProcessOutlineNode: View {
    @Environment(SpawnEventStore.self) private var store
    let record: ProcessRecord

    var body: some View {
        let kids = store.children(of: record.key)
        if kids.isEmpty {
            ProcessTreeRow(record: record)
                .tag(Optional(record.key))
        } else {
            DisclosureGroup {
                ForEach(kids, id: \.key) { child in
                    ProcessOutlineNode(record: child)
                }
            } label: {
                ProcessTreeRow(record: record)
                    .tag(Optional(record.key))
            }
        }
    }
}

private struct ProcessTreeRow: View {
    let record: ProcessRecord

    var body: some View {
        HStack(spacing: 8) {
            statusDot
            Image(systemName: record.children.isEmpty ? "terminal" : "folder")
                .font(.caption)
                .foregroundColor(record.children.isEmpty ? .secondary : .blue)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 1) {
                Text(record.identity.name)
                    .font(.body)
                    .lineLimit(1)
                    .foregroundStyle(record.isAlive ? Color.primary : Color.secondary)

                HStack(spacing: 6) {
                    Text("PID \(record.identity.pid)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)

                    if let duration = record.duration {
                        Text("· \(Format.duration(duration))")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    } else if record.isAlive {
                        Text("· alive")
                            .font(.caption2)
                            .foregroundStyle(.green.opacity(0.8))
                    }
                }
            }

            Spacer(minLength: 0)

            if !record.children.isEmpty {
                Text("\(record.children.count)")
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.blue.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 1)
    }

    @ViewBuilder
    private var statusDot: some View {
        Circle()
            .fill(record.isAlive ? Color.green : (record.wasKilled ? Color.red : Color.secondary.opacity(0.6)))
            .frame(width: 6, height: 6)
    }
}
