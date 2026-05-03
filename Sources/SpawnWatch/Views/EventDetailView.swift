import SwiftUI
import SpawnWatchCore

struct EventDetailView: View {
    @Environment(SpawnEventStore.self) private var store

    var body: some View {
        if let event = store.selectedEvent {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection(event)
                    if let app = event.owningApp {
                        appBundleSection(app, relationship: event.relationship)
                    }
                    statusSection(event)
                    TrustPanelView(record: store.record(for: event.childKey))
                    LineagePanelView(key: event.childKey)
                    processSection("Parent Process", identity: event.parent, record: store.record(for: event.parentKey))
                    processSection("Child Process", identity: event.child, record: store.record(for: event.childKey))
                    commandSection(event)
                    metadataSection(event)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            VStack(spacing: 16) {
                BrandMark(size: 96)
                    .opacity(0.85)
                VStack(spacing: 6) {
                    Text("SpawnWatch")
                        .font(.title2.weight(.bold))
                    Text("App-attributed subprocess tracer for macOS")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Text("Select an event from the list to view full details, code-signing info, and lineage.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }

    @ViewBuilder
    private func headerSection(_ event: SpawnEvent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: headerIcon(for: event.eventType))
                    .font(.title)
                    .foregroundStyle(headerColor(for: event.eventType))
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(event.parent.name)  →  \(event.child.name)")
                        .font(.title2.bold())
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(event.timestamp.formatted(.dateTime.hour().minute().second().secondFraction(.fractional(3))))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    EventTypePill(type: event.eventType)
                    RelationshipPill(relationship: event.relationship)
                }
            }
        }
    }

    @ViewBuilder
    private func statusSection(_ event: SpawnEvent) -> some View {
        if let record = store.record(for: event.childKey) {
            SectionCard(title: "Lifetime", systemImage: "clock", tint: record.isAlive ? .green : .secondary) {
                HStack(alignment: .firstTextBaseline, spacing: 24) {
                    StatTile(label: "Status", value: lifetimeStatus(record), tint: record.isAlive ? .green : (record.wasKilled ? .red : .secondary))
                    StatTile(label: "Duration", value: durationLabel(record), tint: .blue)
                    if let exit = record.exitCode {
                        StatTile(label: "Exit Code", value: "\(exit)", tint: exit == 0 ? .green : .orange)
                    }
                    if let signal = record.terminatingSignal, signal != 0 {
                        StatTile(label: "Signal", value: "SIG \(signal)", tint: .red)
                    }
                    Spacer()
                }
            }
        }
    }

    private func lifetimeStatus(_ record: ProcessRecord) -> String {
        if record.isAlive { return "Alive" }
        if record.wasKilled { return "Killed" }
        if let exit = record.exitCode, exit != 0 { return "Failed" }
        return "Exited"
    }

    private func durationLabel(_ record: ProcessRecord) -> String {
        if let d = record.duration { return Format.duration(d) }
        return Format.relative(from: record.spawnTime)
    }

    @ViewBuilder
    private func appBundleSection(_ app: AppBundleInfo, relationship: ProcessRelationship) -> some View {
        SectionCard(title: "Owning Application", systemImage: "app.fill", tint: .blue) {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                GridRow {
                    Text("App").foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        AppIconView(bundlePath: app.bundlePath, size: 28)
                        Text(app.name).fontWeight(.medium).textSelection(.enabled)
                    }
                }
                GridRow {
                    Text("Bundle Path").foregroundStyle(.secondary)
                    Text(app.bundlePath)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                if let bundleId = app.bundleIdentifier {
                    GridRow {
                        Text("Bundle ID").foregroundStyle(.secondary)
                        Text(bundleId)
                            .font(.system(.callout, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                GridRow {
                    Text("Relationship").foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Text(relationship.rawValue).fontWeight(.medium)
                        relationshipExplanation(relationship)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .font(.callout)
        }
    }

    @ViewBuilder
    private func processSection(_ title: String, identity: ProcessIdentity, record: ProcessRecord?) -> some View {
        SectionCard(title: title, systemImage: title.contains("Parent") ? "arrowshape.up" : "arrowshape.down", tint: .secondary) {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                GridRow {
                    Text("Name").foregroundStyle(.secondary)
                    Text(identity.name).textSelection(.enabled)
                }
                GridRow {
                    Text("PID").foregroundStyle(.secondary)
                    Text("\(identity.pid)").font(.system(.callout, design: .monospaced))
                }
                if let path = identity.executablePath {
                    GridRow {
                        Text("Path").foregroundStyle(.secondary)
                        Text(path)
                            .font(.system(.callout, design: .monospaced))
                            .textSelection(.enabled)
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }
                }
                if let bundle = identity.bundleName {
                    GridRow {
                        Text("Bundle ID").foregroundStyle(.secondary)
                        Text(bundle).textSelection(.enabled)
                    }
                }
                if let record, !record.children.isEmpty {
                    GridRow {
                        Text("Children").foregroundStyle(.secondary)
                        Text("\(record.children.count)")
                    }
                }
            }
            .font(.callout)
        }
    }

    @ViewBuilder
    private func commandSection(_ event: SpawnEvent) -> some View {
        if let args = event.commandLine, !args.isEmpty {
            SectionCard(title: "Command Line", systemImage: "chevron.left.forwardslash.chevron.right", tint: .blue) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(args.joined(separator: " "), forType: .string)
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.borderless)
                        .help("Copy command")
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(args.enumerated()), id: \.offset) { index, arg in
                            HStack(alignment: .top, spacing: 8) {
                                Text("[\(index)]")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 30, alignment: .trailing)
                                Text(arg)
                                    .font(.system(.callout, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    @ViewBuilder
    private func metadataSection(_ event: SpawnEvent) -> some View {
        SectionCard(title: "Metadata", systemImage: "tag", tint: .secondary) {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                GridRow {
                    Text("Source").foregroundStyle(.secondary)
                    Text(event.source.rawValue)
                }
                if let cwd = event.workingDirectory {
                    GridRow {
                        Text("Working Dir").foregroundStyle(.secondary)
                        Text(cwd)
                            .font(.system(.callout, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                GridRow {
                    Text("Event ID").foregroundStyle(.secondary)
                    Text(event.id.uuidString)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .font(.callout)
        }
    }

    private func headerIcon(for type: EventType) -> String {
        switch type {
        case .exec: "bolt.horizontal.fill"
        case .fork: "arrow.branch"
        case .exit: "stop.circle.fill"
        }
    }

    private func headerColor(for type: EventType) -> Color {
        switch type {
        case .exec: .blue
        case .fork: .orange
        case .exit: .red
        }
    }

    @ViewBuilder
    private func relationshipExplanation(_ rel: ProcessRelationship) -> some View {
        switch rel {
        case .xpcService: Text("— launched by launchd on behalf of the app via XPC")
        case .appExtension: Text("— plugin hosted inside the app bundle")
        case .helper: Text("— helper binary bundled with the app")
        case .framework: Text("— system framework service triggered by the app")
        case .directChild: Text("— the main app executable itself")
        case .system: Text("— macOS system process")
        case .unknown: Text("")
        }
    }
}

private struct EventTypePill: View {
    let type: EventType
    var body: some View {
        let (label, tint) = info
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption.weight(.bold))
            Text(label).font(.caption.weight(.bold))
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(tint.opacity(0.18))
        .foregroundStyle(tint)
        .clipShape(Capsule())
    }
    private var icon: String {
        switch type {
        case .exec: "bolt.horizontal"
        case .fork: "arrow.branch"
        case .exit: "stop.circle"
        }
    }
    private var info: (String, Color) {
        switch type {
        case .exec: ("EXEC", .blue)
        case .fork: ("FORK", .orange)
        case .exit: ("EXIT", .red)
        }
    }
}

private struct RelationshipPill: View {
    let relationship: ProcessRelationship
    var body: some View {
        Text(relationship.rawValue)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(relationshipColor(relationship).opacity(0.16))
            .foregroundStyle(relationshipColor(relationship))
            .clipShape(Capsule())
    }
}

private struct StatTile: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(.caption2, design: .default, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(tint)
                .lineLimit(1)
        }
    }
}
