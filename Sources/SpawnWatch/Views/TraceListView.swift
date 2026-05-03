import SwiftUI
import SpawnWatchCore

struct TraceListView: View {
    let traceController: TraceController
    @State private var openSession: TraceSession?
    @State private var renamingSession: TraceSession?
    @State private var renameDraft: String = ""

    var body: some View {
        Group {
            if traceController.savedSessions.isEmpty {
                emptyState
            } else {
                List(traceController.savedSessions) { session in
                    Button {
                        openSession = session
                    } label: {
                        TraceSessionRow(session: session)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Open") { openSession = session }
                        Button("Rename…") {
                            renameDraft = session.name
                            renamingSession = session
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            traceController.delete(session)
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .sheet(item: $openSession) { session in
            TraceSessionView(session: session) {
                openSession = nil
            }
        }
        .sheet(item: $renamingSession) { session in
            VStack(alignment: .leading, spacing: 14) {
                Text("Rename trace").font(.title3.bold())
                TextField("Name", text: $renameDraft)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Spacer()
                    Button("Cancel") { renamingSession = nil }
                    Button("Save") {
                        traceController.rename(session, to: renameDraft)
                        renamingSession = nil
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(width: 400)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            BrandMark(size: 64)
                .opacity(0.9)
            Text("No traces yet")
                .font(.headline)
            Text("Click \"Start Trace\" in the toolbar, run a command, then stop. Traces are saved here for later review and comparison.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 32)
    }
}

private struct TraceSessionRow: View {
    let session: TraceSession

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        return f
    }()

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "record.circle.fill")
                .foregroundStyle(.red)
                .font(.body)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(Self.dateFormatter.string(from: session.startTime))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(Format.duration(session.duration))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("\(session.events.count) events")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 3)
    }
}
