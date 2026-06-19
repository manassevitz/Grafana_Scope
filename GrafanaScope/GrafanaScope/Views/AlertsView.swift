import SwiftUI

struct AlertsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            header
            summaryBanner
            Divider()
            ScrollView {
                LazyVStack(spacing: 10) {
                    if model.snapshot.groups.isEmpty {
                        Text("Add a Grafana instance in Settings")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 120)
                    } else {
                        ForEach(model.snapshot.groups) { group in
                            InstanceGroupView(group: group)
                        }
                    }
                }
                .padding(12)
            }
        }
        .frame(width: 380, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Grafana Scope")
                    .font(.headline)
                Text(model.snapshot.isLoading ? "Updating…" : "Last updated: \(formatUpdated(model.snapshot.lastUpdated))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await model.refreshAlerts() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh")

            Menu {
                MenuBarCommands()
            } label: {
                Image(systemName: "gearshape")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Settings and more")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var summaryBanner: some View {
        let groups = model.snapshot.groups
        let total = model.snapshot.totalCount

        Group {
            if groups.isEmpty {
                banner("No instances. Open Settings to add Grafana.", tone: .ok)
            } else if total > 0 {
                banner("\(total) active alert\(total == 1 ? "" : "s")", tone: .warn)
            } else {
                banner("No active alerts across any instance", tone: .ok)
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }

    private enum BannerTone {
        case ok, warn, error
    }

    private func banner(_ text: String, tone: BannerTone) -> some View {
        let color: Color = switch tone {
        case .ok: .green
        case .warn: .orange
        case .error: .red
        }

        return Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InstanceGroupView: View {
    @EnvironmentObject private var model: AppModel
    let group: InstanceAlertGroup

    private var collapsed: Bool {
        model.isGroupCollapsed(group)
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                model.toggleGroup(group)
            } label: {
                HStack {
                    Image(systemName: collapsed ? "chevron.right" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Circle()
                        .fill(Color(hex: group.instance.colorHex))
                        .frame(width: 10, height: 10)
                    Text(group.instance.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(group.alerts.count)")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            group.alerts.isEmpty
                                ? Color.secondary.opacity(0.2)
                                : Color(hex: group.instance.colorHex)
                        )
                        .foregroundStyle(group.alerts.isEmpty ? Color.primary : Color.white)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(hex: group.instance.colorHex).opacity(group.alerts.isEmpty && group.error == nil ? 0.08 : 0.16))
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color(hex: group.instance.colorHex))
                        .frame(width: 4)
                }
            }
            .buttonStyle(.plain)

            if !collapsed {
                VStack(alignment: .leading, spacing: 8) {
                    if let error = group.error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 12)
                    } else if group.alerts.isEmpty {
                        Text("No active alerts")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                    } else {
                        ForEach(group.alerts) { alert in
                            AlertRowView(alert: alert, colorHex: group.instance.colorHex)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.08))
        )
    }
}

struct AlertRowView: View {
    let alert: NormalizedAlert
    let colorHex: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if SeverityStyle.from(alert.severity) != .unknown {
                Text(alert.severity)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(severityColor.opacity(0.18))
                    .foregroundStyle(severityColor)
                    .clipShape(Capsule())
            }
            Text(alert.alertName)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(hex: colorHex).opacity(0.1))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color(hex: colorHex))
                .frame(width: 3)
        }
        .padding(.horizontal, 8)
    }

    private var severityColor: Color {
        switch SeverityStyle.from(alert.severity) {
        case .critical: return .red
        case .warning: return .orange
        case .low: return .blue
        case .unknown: return .secondary
        }
    }
}
