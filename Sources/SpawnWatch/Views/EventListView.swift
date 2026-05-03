import SwiftUI
import SpawnWatchCore

struct EventListView: View {
    @Environment(SpawnEventStore.self) private var store
    let events: [SpawnEvent]

    var body: some View {
        @Bindable var store = store

        List(events, selection: $store.selectedEvent) { event in
            EventRow(event: event, record: store.record(for: event.childKey))
                .tag(event)
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .overlay {
            if events.isEmpty {
                VStack(spacing: 14) {
                    BrandMark(size: 80)
                        .opacity(0.85)
                    Text(store.searchText.isEmpty ? "Waiting for processes to spawn…" : "No events match your filters")
                        .font(.headline)
                    Text(store.searchText.isEmpty
                         ? "Run a command in Terminal — events will appear here in real time."
                         : "Try clearing search or relaxing the event-type filters above.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct EventRow: View {
    let event: SpawnEvent
    let record: ProcessRecord?

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(Self.timeFormatter.string(from: event.timestamp))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 90, alignment: .leading)

                EventTypeTag(type: event.eventType)
                RelationshipTag(relationship: event.relationship)

                HStack(spacing: 4) {
                    Text(event.parent.name)
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(event.child.name)
                        .fontWeight(.medium)
                }
                .lineLimit(1)

                Spacer(minLength: 4)

                trailingStatus
            }

            secondaryRow
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var trailingStatus: some View {
        if event.eventType == .exit {
            ExitBadge(exitCode: event.exitCode, signal: event.terminatingSignal)
        } else if let record, let duration = record.duration {
            Text(Format.duration(duration))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
        } else if let record, record.isAlive {
            Text("alive")
                .font(.caption2)
                .foregroundStyle(Color.green.opacity(0.8))
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var secondaryRow: some View {
        if let app = event.owningApp {
            HStack(spacing: 4) {
                AppIconView(bundlePath: app.bundlePath, size: 12, fallbackSystemImage: "app.fill", fallbackColor: .blue)
                Text(app.name)
                    .font(.caption)
                    .foregroundStyle(.blue)
                if let args = event.commandLine, args.count > 1 {
                    Text("·").foregroundStyle(.tertiary)
                    Text(args.dropFirst().joined(separator: " "))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(.leading, 98)
        } else if let args = event.commandLine, !args.isEmpty {
            Text(args.joined(separator: " "))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.leading, 98)
        }
    }
}

private struct EventTypeTag: View {
    let type: EventType
    var body: some View {
        let (label, tint) = info
        Text(label)
            .font(.system(.caption2, design: .monospaced, weight: .bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(tint.opacity(0.18))
            .foregroundStyle(tint)
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private var info: (String, Color) {
        switch type {
        case .exec: ("EXEC", .blue)
        case .fork: ("FORK", .orange)
        case .exit: ("EXIT", .red)
        }
    }
}

private struct RelationshipTag: View {
    let relationship: ProcessRelationship
    var body: some View {
        Text(relationship.rawValue)
            .font(.system(.caption2))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(relationshipColor(relationship).opacity(0.14))
            .foregroundStyle(relationshipColor(relationship))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

struct ExitBadge: View {
    let exitCode: Int32?
    let signal: Int32?

    var body: some View {
        HStack(spacing: 4) {
            if let signal, signal != 0 {
                Image(systemName: "bolt.slash.fill")
                    .font(.caption2)
                Text("SIG \(signal)")
                    .font(.system(.caption2, design: .monospaced, weight: .semibold))
            } else if let exitCode, exitCode != 0 {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                Text("\(exitCode)")
                    .font(.system(.caption2, design: .monospaced, weight: .semibold))
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                Text("ok")
                    .font(.system(.caption2, design: .monospaced))
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 1)
        .background(badgeColor.opacity(0.18))
        .foregroundStyle(badgeColor)
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    private var badgeColor: Color {
        if let signal, signal != 0 { return .red }
        if let exitCode, exitCode != 0 { return .orange }
        return .green
    }
}

func relationshipColor(_ rel: ProcessRelationship) -> Color {
    switch rel {
    case .xpcService: .purple
    case .appExtension: .orange
    case .helper: .green
    case .framework: .cyan
    case .directChild: .blue
    case .system: .gray
    case .unknown: .secondary
    }
}
