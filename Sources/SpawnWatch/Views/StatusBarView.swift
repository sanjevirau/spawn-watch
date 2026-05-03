import SwiftUI

struct StatusBarView: View {
    let status: String
    let eventCount: Int
    let isPaused: Bool
    let aliveCount: Int
    let appCount: Int
    let isRecording: Bool

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)
                Text(status)
                    .font(.system(.caption, design: .monospaced))
            }

            Divider().frame(height: 11)

            Pill(label: "events", value: "\(eventCount.formatted())", tint: .blue)
            Pill(label: "alive", value: "\(aliveCount.formatted())", tint: .green)
            Pill(label: "apps", value: "\(appCount.formatted())", tint: .indigo)

            if isPaused {
                Divider().frame(height: 11)
                Text("PAUSED")
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }

            if isRecording {
                Divider().frame(height: 11)
                HStack(spacing: 4) {
                    Circle().fill(Color.red).frame(width: 6, height: 6)
                    Text("RECORDING")
                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                        .foregroundStyle(.red)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Color.red.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(.bar)
    }

    private var statusColor: Color {
        switch status {
        case "Stopped", "Idle": .red
        case "Starting…": .orange
        default: .green
        }
    }
}

private struct Pill: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 3) {
            Text(value)
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .foregroundStyle(tint)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
