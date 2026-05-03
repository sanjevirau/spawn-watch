import SwiftUI
import SpawnWatchCore

struct LineagePanelView: View {
    @Environment(SpawnEventStore.self) private var store
    let key: ProcessKey?

    var body: some View {
        SectionCard(title: "Lineage", systemImage: "point.3.connected.trianglepath.dotted", tint: .indigo) {
            if let key {
                let chain = Array(store.lineage(for: key).reversed())
                if chain.isEmpty {
                    Text("No lineage available")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(chain.enumerated()), id: \.offset) { index, record in
                            LineageRow(
                                record: record,
                                isFirst: index == 0,
                                isLast: index == chain.count - 1,
                                isLeaf: record.key == key
                            )
                        }
                    }
                }
            } else {
                Text("Select an event to view its ancestor chain")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct LineageRow: View {
    let record: ProcessRecord
    let isFirst: Bool
    let isLast: Bool
    let isLeaf: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                if !isFirst {
                    Rectangle().fill(Color.indigo.opacity(0.4)).frame(width: 1, height: 8)
                } else {
                    Color.clear.frame(width: 1, height: 8)
                }
                Circle()
                    .fill(isLeaf ? Color.indigo : Color.indigo.opacity(0.6))
                    .frame(width: 8, height: 8)
                if !isLast {
                    Rectangle().fill(Color.indigo.opacity(0.4)).frame(width: 1)
                } else {
                    Color.clear.frame(width: 1)
                }
            }
            .frame(width: 8)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(record.identity.name)
                        .font(.callout.weight(isLeaf ? .semibold : .regular))
                    Text("PID \(record.identity.pid)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                    if record.isAlive {
                        Circle().fill(Color.green).frame(width: 5, height: 5)
                    } else if record.wasKilled {
                        Image(systemName: "bolt.slash.fill").font(.caption2).foregroundStyle(.red)
                    }
                }
                if let path = record.identity.executablePath {
                    Text(path)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding(.vertical, 2)
        }
    }
}
