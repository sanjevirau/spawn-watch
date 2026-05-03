import SwiftUI
import SpawnWatchCore

struct AppGroupListView: View {
    let groups: [String: [SpawnEvent]]
    @Binding var selectedApp: String?

    private var sortedKeys: [String] {
        groups.keys.sorted { lhs, rhs in
            if lhs == "System / Other" { return false }
            if rhs == "System / Other" { return true }
            return (groups[lhs]?.count ?? 0) > (groups[rhs]?.count ?? 0)
        }
    }

    private func bundlePath(forGroup name: String) -> String? {
        guard name != "System / Other" else { return nil }
        return groups[name]?.first(where: { $0.owningApp != nil })?.owningApp?.bundlePath
    }

    var body: some View {
        List(sortedKeys, id: \.self, selection: $selectedApp) { appName in
            let events = groups[appName] ?? []
            let relationships = Set(events.map(\.relationship))

            HStack(spacing: 9) {
                if appName == "System / Other" {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.secondary)
                        .frame(width: 22, height: 22)
                } else {
                    AppIconView(
                        bundlePath: bundlePath(forGroup: appName),
                        size: 22
                    )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(appName)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        ForEach(Array(relationships).sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { rel in
                            Text(rel.rawValue)
                                .font(.system(.caption2))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(relationshipColor(rel).opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                }

                Spacer()

                Text("\(events.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }
            .padding(.vertical, 3)
            .tag(appName)
        }
    }

    private func relationshipColor(_ rel: ProcessRelationship) -> Color {
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
}
