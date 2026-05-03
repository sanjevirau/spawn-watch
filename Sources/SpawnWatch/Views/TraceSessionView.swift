import SwiftUI
import SpawnWatchCore

struct TraceSessionView: View {
    let session: TraceSession
    let onClose: () -> Void

    @State private var selectedKey: ProcessKey?
    @State private var showOnlyApps: Bool = false
    @State private var showOnlyFailed: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            statsBar
            Divider()
            HSplitView {
                treeColumn
                    .frame(minWidth: 360)
                detailColumn
                    .frame(minWidth: 380)
            }
        }
        .frame(minWidth: 1080, minHeight: 680)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "record.circle.fill")
                .foregroundStyle(.red)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name).font(.title3.bold())
                Text(session.startTime.formatted(date: .abbreviated, time: .standard))
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
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var statsBar: some View {
        HStack(spacing: 20) {
            StatBlock(label: "Duration", value: Format.duration(session.duration), tint: .blue)
            StatBlock(label: "Events", value: "\(session.events.count)", tint: .indigo)
            StatBlock(label: "Processes", value: "\(session.processes.count)", tint: .purple)
            StatBlock(label: "Failed", value: "\(session.failedCount)", tint: session.failedCount > 0 ? .orange : .secondary)
            StatBlock(label: "Unsigned", value: "\(session.unsignedCount)", tint: session.unsignedCount > 0 ? .red : .secondary)
            Spacer()

            HStack(spacing: 6) {
                Toggle("Apps only", isOn: $showOnlyApps).toggleStyle(.button)
                Toggle("Failed only", isOn: $showOnlyFailed).toggleStyle(.button)
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.06))
    }

    private var filteredRoots: [ProcessSnapshot] {
        var roots = session.rootProcesses
        if showOnlyApps {
            roots = roots.filter { $0.owningApp != nil || hasAppDescendant($0) }
        }
        if showOnlyFailed {
            roots = roots.filter { hasFailedDescendant($0) }
        }
        return roots.sorted { $0.spawnTime < $1.spawnTime }
    }

    private func hasAppDescendant(_ snapshot: ProcessSnapshot) -> Bool {
        if snapshot.owningApp != nil { return true }
        for child in session.children(of: snapshot.key) {
            if hasAppDescendant(child) { return true }
        }
        return false
    }

    private func hasFailedDescendant(_ snapshot: ProcessSnapshot) -> Bool {
        if (snapshot.exitCode ?? 0) != 0 || snapshot.wasKilled { return true }
        for child in session.children(of: snapshot.key) {
            if hasFailedDescendant(child) { return true }
        }
        return false
    }

    private var treeColumn: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Process Tree").font(.headline)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            Divider()
            List(selection: $selectedKey) {
                ForEach(filteredRoots, id: \.key) { snap in
                    snapshotOutline(snap)
                }
            }
            .listStyle(.sidebar)
        }
    }

    private func snapshotOutline(_ snapshot: ProcessSnapshot) -> some View {
        SnapshotOutlineNode(snapshot: snapshot, session: session)
    }

    @ViewBuilder
    private var detailColumn: some View {
        if let key = selectedKey, let snapshot = session.record(for: key) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(snapshot.identity.name)
                        .font(.title3.bold())
                    SectionCard(title: "Lifetime", systemImage: "clock", tint: snapshot.isAlive ? .green : .secondary) {
                        HStack(spacing: 24) {
                            tile("Status", value: lifetimeStatus(snapshot), tint: snapshot.isAlive ? .green : (snapshot.wasKilled ? .red : .secondary))
                            tile("Duration", value: snapshot.duration.map { Format.duration($0) } ?? "—", tint: .blue)
                            if let code = snapshot.exitCode {
                                tile("Exit Code", value: "\(code)", tint: code == 0 ? .green : .orange)
                            }
                            if let signal = snapshot.terminatingSignal, signal != 0 {
                                tile("Signal", value: "SIG \(signal)", tint: .red)
                            }
                            Spacer()
                        }
                    }
                    if let trust = snapshot.trust {
                        SnapshotTrustView(trust: trust)
                    }
                    if let args = snapshot.commandLine, !args.isEmpty {
                        SectionCard(title: "Command Line", systemImage: "chevron.left.forwardslash.chevron.right", tint: .blue) {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(args.enumerated()), id: \.offset) { idx, arg in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("[\(idx)]")
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundStyle(.tertiary)
                                            .frame(width: 30, alignment: .trailing)
                                        Text(arg).font(.system(.callout, design: .monospaced))
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                        }
                    }
                    if let app = snapshot.owningApp {
                        SectionCard(title: "Owning App", systemImage: "app.fill", tint: .blue) {
                            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                                GridRow {
                                    Text("Name").foregroundStyle(.secondary)
                                    Text(app.name)
                                }
                                if let bid = app.bundleIdentifier {
                                    GridRow {
                                        Text("Bundle ID").foregroundStyle(.secondary)
                                        Text(bid).font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                                    }
                                }
                                GridRow {
                                    Text("Path").foregroundStyle(.secondary)
                                    Text(app.bundlePath).font(.system(.callout, design: .monospaced))
                                        .textSelection(.enabled)
                                        .lineLimit(2)
                                        .truncationMode(.middle)
                                }
                            }
                            .font(.callout)
                        }
                    }
                }
                .padding(18)
            }
        } else {
            ContentUnavailableView {
                Label("Pick a process", systemImage: "cursorarrow.click.2")
            } description: {
                Text("Select a process in the tree to see its details, signing info, and command line.")
            }
        }
    }

    private func lifetimeStatus(_ snapshot: ProcessSnapshot) -> String {
        if snapshot.isAlive { return "Still alive" }
        if snapshot.wasKilled { return "Killed" }
        if let code = snapshot.exitCode, code != 0 { return "Failed" }
        return "Exited"
    }

    @ViewBuilder
    private func tile(_ label: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(.caption2, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(tint)
                .lineLimit(1)
        }
    }
}

private struct SnapshotOutlineNode: View {
    let snapshot: ProcessSnapshot
    let session: TraceSession

    var body: some View {
        let kids = session.children(of: snapshot.key)
        if kids.isEmpty {
            SnapshotRow(snapshot: snapshot)
                .tag(Optional(snapshot.key))
        } else {
            DisclosureGroup {
                ForEach(kids, id: \.key) { child in
                    SnapshotOutlineNode(snapshot: child, session: session)
                }
            } label: {
                SnapshotRow(snapshot: snapshot)
                    .tag(Optional(snapshot.key))
            }
        }
    }
}

private struct SnapshotRow: View {
    let snapshot: ProcessSnapshot
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Image(systemName: snapshot.children.isEmpty ? "terminal" : "folder")
                .font(.caption)
                .foregroundStyle(snapshot.children.isEmpty ? Color.secondary : Color.blue)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(snapshot.identity.name).font(.body).lineLimit(1)
                HStack(spacing: 6) {
                    Text("PID \(snapshot.identity.pid)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                    if let dur = snapshot.duration {
                        Text("· \(Format.duration(dur))")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    if (snapshot.exitCode ?? 0) != 0 {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 1)
    }

    private var statusColor: Color {
        if snapshot.isAlive { return .green }
        if snapshot.wasKilled { return .red }
        if (snapshot.exitCode ?? 0) != 0 { return .orange }
        return .secondary.opacity(0.6)
    }
}

private struct StatBlock: View {
    let label: String
    let value: String
    let tint: Color
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

private struct SnapshotTrustView: View {
    let trust: TrustInfo
    var body: some View {
        SectionCard(title: "Trust", systemImage: "checkmark.shield.fill", tint: tint) {
            HStack(spacing: 8) {
                Text(trust.summary)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(tint)
                if trust.notarized { SmallTag("Notarized", color: .green) }
                if trust.hardenedRuntime { SmallTag("Hardened", color: .blue) }
                if trust.sandboxed { SmallTag("Sandboxed", color: .purple) }
                Spacer()
            }
        }
    }

    private var tint: Color {
        switch trust.signingType {
        case .apple, .appStore: return .green
        case .developerID: return .blue
        case .adhoc: return .yellow
        case .unsigned: return .red
        case .unknown: return .secondary
        }
    }
}
