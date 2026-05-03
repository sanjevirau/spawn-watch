import SwiftUI
import SpawnWatchCore

struct TrustPanelView: View {
    let record: ProcessRecord?

    var body: some View {
        SectionCard(title: "Trust", systemImage: "checkmark.shield.fill", tint: tint) {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if let record {
            switch record.trustState {
            case .pending:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Inspecting code signature…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            case .unknown:
                Text("Not yet inspected")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            case .failed(let msg):
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(msg)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            case .ready:
                if let info = record.trust {
                    trustGrid(info)
                } else {
                    Text("No signing information available")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Text("Select an event to inspect its binary")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var tint: Color {
        guard let record, let info = record.trust else { return .secondary }
        switch info.signingType {
        case .apple, .appStore: return .green
        case .developerID: return info.notarized ? .green : .blue
        case .adhoc: return .yellow
        case .unsigned: return .red
        case .unknown: return .secondary
        }
    }

    @ViewBuilder
    private func trustGrid(_ info: TrustInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SigningBadge(type: info.signingType)
                if info.notarized {
                    Capsule()
                        .fill(Color.green.opacity(0.18))
                        .overlay(
                            HStack(spacing: 4) {
                                Image(systemName: "seal.fill").font(.caption2)
                                Text("Notarized").font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(.green)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                        )
                        .fixedSize()
                }
                if info.hardenedRuntime {
                    SmallTag("Hardened Runtime", color: .blue)
                }
                if info.libraryValidation {
                    SmallTag("Library Validation", color: .blue)
                }
                if info.sandboxed {
                    SmallTag("Sandboxed", color: .purple)
                }
                Spacer()
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 5) {
                if let team = info.teamID {
                    Row(label: "Team ID", value: team, monospaced: true)
                }
                if !info.signingAuthority.isEmpty {
                    GridRow(alignment: .top) {
                        Text("Authority").foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(info.signingAuthority, id: \.self) { line in
                                Text(line).textSelection(.enabled)
                            }
                        }
                    }
                }
                if info.entitlementCount > 0 {
                    Row(label: "Entitlements", value: "\(info.entitlementCount)")
                }
                if let cd = info.cdHash {
                    Row(label: "cdhash", value: cd, monospaced: true, truncate: true)
                }
                if let sha = info.sha256 {
                    Row(label: "SHA-256", value: sha, monospaced: true, truncate: true)
                }
            }
            .font(.callout)
        }
    }
}

private struct Row: View {
    let label: String
    let value: String
    var monospaced: Bool = false
    var truncate: Bool = false

    var body: some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            if truncate {
                Text(value.prefix(48) + (value.count > 48 ? "…" : ""))
                    .font(monospaced ? .system(.callout, design: .monospaced) : .callout)
                    .textSelection(.enabled)
                    .help(value)
            } else {
                Text(value)
                    .font(monospaced ? .system(.callout, design: .monospaced) : .callout)
                    .textSelection(.enabled)
            }
        }
    }
}

private struct SigningBadge: View {
    let type: SigningType
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption2.weight(.bold))
            Text(type.rawValue).font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(color.opacity(0.18))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }

    private var icon: String {
        switch type {
        case .apple, .appStore: "applelogo"
        case .developerID: "person.badge.shield.checkmark.fill"
        case .adhoc: "questionmark.diamond.fill"
        case .unsigned: "exclamationmark.shield.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }

    private var color: Color {
        switch type {
        case .apple, .appStore: .green
        case .developerID: .blue
        case .adhoc: .yellow
        case .unsigned: .red
        case .unknown: .secondary
        }
    }
}

struct SmallTag: View {
    let text: String
    let color: Color
    init(_ text: String, color: Color) { self.text = text; self.color = color }
    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(color.opacity(0.16))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
