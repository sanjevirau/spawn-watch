import SwiftUI
import AppKit
import SpawnWatchCore

struct MainContentView: View {
    @Environment(SpawnEventStore.self) private var store
    @Environment(TraceController.self) private var traceController
    @State private var selectedKey: ProcessKey?
    @State private var showExecEvents = true
    @State private var showForkEvents = true
    @State private var showExitEvents = true
    @State private var onlyAppSpawns = false
    @State private var sidebarMode: SidebarMode = .apps
    @State private var selectedAppFilter: String?
    @State private var traceNameDraft: String = ""
    @State private var showTraceNamePrompt = false
    @State private var diffSelection: [TraceSession] = []
    @State private var showDiffPicker = false

    enum SidebarMode: String, CaseIterable, Hashable {
        case apps = "By App"
        case tree = "By Process"
        case traces = "Traces"
    }

    var body: some View {
        @Bindable var store = store

        VStack(spacing: 0) {
            NavigationSplitView {
                sidebar
                    .navigationTitle("SpawnWatch")
                    .navigationSplitViewColumnWidth(min: 240, ideal: 280)
            } content: {
                VStack(spacing: 0) {
                    FilterBarView(
                        showExecEvents: $showExecEvents,
                        showForkEvents: $showForkEvents,
                        showExitEvents: $showExitEvents,
                        onlyAppSpawns: $onlyAppSpawns,
                        hideSystemNoise: $store.hideSystemNoise
                    )
                    Divider()
                    EventListView(events: displayedEvents)
                }
                .navigationSplitViewColumnWidth(min: 420, ideal: 540)
            } detail: {
                EventDetailView()
            }
            .searchable(text: $store.searchText, prompt: "Filter by name, path, argv, app, bundle ID…")
            .toolbar {
                ToolbarItemGroup(placement: .principal) {
                    TraceRecordControl(
                        traceController: traceController,
                        showNamePrompt: $showTraceNamePrompt,
                        nameDraft: $traceNameDraft
                    )
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        store.togglePause()
                    } label: {
                        Image(systemName: store.isPaused ? "play.fill" : "pause.fill")
                    }
                    .help(store.isPaused ? "Resume" : "Pause")

                    Button {
                        store.clearEvents()
                        selectedKey = nil
                    } label: {
                        Image(systemName: "trash")
                    }
                    .help("Clear events")

                    Button {
                        showDiffPicker = true
                    } label: {
                        Image(systemName: "arrow.left.arrow.right.circle")
                    }
                    .help("Compare two traces")
                    .disabled(traceController.savedSessions.count < 2)

                    Button {
                        exportEvents()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .help("Export visible events")
                    .disabled(displayedEvents.isEmpty)
                }
            }

            StatusBarView(
                status: store.monitorStatus,
                eventCount: store.eventCount,
                isPaused: store.isPaused,
                aliveCount: aliveCount,
                appCount: store.appGroups.count,
                isRecording: traceController.isRecording
            )
        }
        .onAppear {
            store.startMonitoring()
            traceController.bind(eventStore: store)
            traceController.loadSavedSessions()
        }
        .onDisappear {
            store.stopMonitoring()
        }
        .sheet(isPresented: $showTraceNamePrompt) {
            TraceNameSheet(
                draft: $traceNameDraft,
                onSave: { name in
                    traceController.startTrace(name: name)
                    showTraceNamePrompt = false
                    traceNameDraft = ""
                },
                onCancel: {
                    showTraceNamePrompt = false
                    traceNameDraft = ""
                }
            )
        }
        .sheet(isPresented: $showDiffPicker) {
            TraceDiffPickerView(
                sessions: traceController.savedSessions,
                onPick: { a, b in
                    diffSelection = [a, b]
                    showDiffPicker = false
                },
                onCancel: { showDiffPicker = false }
            )
        }
        .sheet(isPresented: Binding(
            get: { diffSelection.count == 2 },
            set: { if !$0 { diffSelection = [] } }
        )) {
            if diffSelection.count == 2 {
                TraceDiffView(left: diffSelection[0], right: diffSelection[1]) {
                    diffSelection = []
                }
            }
        }
    }

    @ViewBuilder
    private var sidebar: some View {
        VStack(spacing: 0) {
            Picker("View", selection: $sidebarMode) {
                ForEach(SidebarMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Divider()

            switch sidebarMode {
            case .apps:
                AppGroupListView(
                    groups: store.appGroups,
                    selectedApp: Binding(
                        get: { selectedAppFilter },
                        set: { newVal in
                            selectedKey = nil
                            selectedAppFilter = newVal
                        }
                    )
                )
            case .tree:
                ProcessTreeView(roots: store.rootRecords, selectedKey: $selectedKey)
            case .traces:
                TraceListView(traceController: traceController)
            }
        }
    }

    private var aliveCount: Int {
        store.processes.values.lazy.filter { $0.isAlive }.count
    }

    private var displayedEvents: [SpawnEvent] {
        var result = store.filteredEvents

        if !showExecEvents {
            result = result.filter { $0.eventType != .exec }
        }
        if !showForkEvents {
            result = result.filter { $0.eventType != .fork }
        }
        if !showExitEvents {
            result = result.filter { $0.eventType != .exit }
        }
        if onlyAppSpawns {
            result = result.filter { $0.owningApp != nil }
        }
        if let key = selectedKey {
            result = result.filter { $0.parentKey == key || $0.childKey == key }
        }
        if let appName = selectedAppFilter {
            result = result.filter { ($0.owningApp?.name ?? "System / Other") == appName }
        }

        return result
    }

    private func exportEvents() {
        let events = displayedEvents
        guard !events.isEmpty else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = exportFilename()
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(events)
            try data.write(to: url)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Export Failed"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    private func exportFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = formatter.string(from: Date())

        if let appName = selectedAppFilter {
            let safe = appName.replacingOccurrences(of: " ", with: "_")
            return "spawnwatch_\(safe)_\(timestamp).json"
        }
        if let key = selectedKey, let record = store.record(for: key) {
            return "spawnwatch_\(record.identity.name)_\(timestamp).json"
        }
        return "spawnwatch_\(timestamp).json"
    }
}

private struct TraceRecordControl: View {
    let traceController: TraceController
    @Binding var showNamePrompt: Bool
    @Binding var nameDraft: String

    var body: some View {
        HStack(spacing: 6) {
            if traceController.isRecording {
                Button {
                    traceController.stopTrace()
                } label: {
                    HStack(spacing: 6) {
                        RecordingPulse()
                        Text("Stop Trace")
                            .font(.system(.callout, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.18))
                    .foregroundStyle(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                if let trace = traceController.currentTrace {
                    Text(trace.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    LiveDurationLabel(start: trace.startTime)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("· \(trace.events.count) events")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    nameDraft = ""
                    showNamePrompt = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "record.circle")
                        Text("Start Trace")
                            .font(.system(.callout, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.10))
                    .foregroundStyle(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct RecordingPulse: View {
    @State private var pulse = false
    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 8, height: 8)
            .opacity(pulse ? 0.4 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
    }
}

private struct LiveDurationLabel: View {
    let start: Date
    @State private var now = Date()

    var body: some View {
        Text(Format.relative(from: start, to: now))
            .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { now = $0 }
    }
}

private struct TraceNameSheet: View {
    @Binding var draft: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Start Trace")
                .font(.title2.bold())
            Text("Give this trace a name. Leave blank to auto-name by timestamp.")
                .font(.callout)
                .foregroundStyle(.secondary)
            TextField("e.g., npm install · my-app", text: $draft)
                .textFieldStyle(.roundedBorder)
                .onSubmit { onSave(draft) }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Start") { onSave(draft) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}

private struct TraceDiffPickerView: View {
    let sessions: [TraceSession]
    let onPick: (TraceSession, TraceSession) -> Void
    let onCancel: () -> Void
    @State private var first: TraceSession?
    @State private var second: TraceSession?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Compare Two Traces")
                .font(.title2.bold())
            Text("Pick a baseline and a comparison run.")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Baseline (A)").font(.caption).foregroundStyle(.secondary)
                Picker("Baseline", selection: $first) {
                    Text("Select…").tag(Optional<TraceSession>.none)
                    ForEach(sessions) { session in
                        Text(session.name).tag(Optional(session))
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()

                Text("Comparison (B)").font(.caption).foregroundStyle(.secondary)
                Picker("Comparison", selection: $second) {
                    Text("Select…").tag(Optional<TraceSession>.none)
                    ForEach(sessions) { session in
                        Text(session.name).tag(Optional(session))
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Compare") {
                    if let a = first, let b = second, a.id != b.id { onPick(a, b) }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(first == nil || second == nil || first?.id == second?.id)
            }
        }
        .padding(20)
        .frame(width: 480)
    }
}
