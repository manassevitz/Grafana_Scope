import Foundation

struct AppConfig: Codable, Equatable {
    var instances: [GrafanaInstance]
    var refreshIntervalSeconds: Int

    static let `default` = AppConfig(instances: [], refreshIntervalSeconds: 60)
}

struct GrafanaInstance: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var url: String
    var apiToken: String
    var enabled: Bool
    var colorHex: String

    enum CodingKeys: String, CodingKey {
        case id, name, url, apiToken, enabled
        case colorHex = "color"
    }
}

struct NormalizedAlert: Identifiable, Equatable {
    let id: String
    let instanceId: UUID
    let instanceName: String
    let alertName: String
    let summary: String
    let description: String
    let severity: String
    let state: String
    let startsAt: Date?
    let isFiring: Bool
}

struct InstanceAlertGroup: Identifiable, Equatable {
    var id: UUID { instance.id }
    let instance: GrafanaInstance
    let alerts: [NormalizedAlert]
    let error: String?
}

struct AlertsSnapshot: Equatable {
    var groups: [InstanceAlertGroup]
    var totalCount: Int
    var lastUpdated: Date?
    var isLoading: Bool

    static let empty = AlertsSnapshot(groups: [], totalCount: 0, lastUpdated: nil, isLoading: false)
}

enum InstanceColors {
    static let palette = [
        "#FF453A", "#FF9F0A", "#FFD60A", "#30D158",
        "#0A84FF", "#BF5AF2", "#FF375F", "#64D2FF",
    ]

    static func defaultColor(for index: Int) -> String {
        palette[index % palette.count]
    }
}

enum SeverityStyle {
    case critical
    case warning
    case low
    case unknown

    static func from(_ severity: String) -> SeverityStyle {
        let value = severity.lowercased()
        if ["critical", "high", "page"].contains(value) { return .critical }
        if ["warning", "warn", "medium"].contains(value) { return .warning }
        if ["low", "info"].contains(value) { return .low }
        return .unknown
    }
}
