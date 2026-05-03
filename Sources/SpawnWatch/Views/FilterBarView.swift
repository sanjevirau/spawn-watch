import SwiftUI
import SpawnWatchCore

struct FilterBarView: View {
    @Binding var showExecEvents: Bool
    @Binding var showForkEvents: Bool
    @Binding var showExitEvents: Bool
    @Binding var onlyAppSpawns: Bool
    @Binding var hideSystemNoise: Bool

    var body: some View {
        HStack(spacing: 8) {
            FilterChip(label: "exec", systemImage: "bolt.horizontal", color: .blue, isOn: $showExecEvents)
            FilterChip(label: "fork", systemImage: "arrow.branch", color: .orange, isOn: $showForkEvents)
            FilterChip(label: "exit", systemImage: "stop.circle", color: .red, isOn: $showExitEvents)

            Divider().frame(height: 14)

            FilterChip(label: "Apps only", systemImage: "app.dashed", color: .indigo, isOn: $onlyAppSpawns)
            FilterChip(label: "Hide noise", systemImage: "wind", color: .gray, isOn: $hideSystemNoise)
                .help("Hide mdworker, xpcproxy, trustd, and other system noise")

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

private struct FilterChip: View {
    let label: String
    let systemImage: String
    let color: Color
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(.system(.caption, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isOn ? color.opacity(0.18) : Color.secondary.opacity(0.08))
            .foregroundStyle(isOn ? color : Color.secondary)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(isOn ? color.opacity(0.4) : Color.clear, lineWidth: 0.6)
            )
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }
}
