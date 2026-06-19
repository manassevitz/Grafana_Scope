import Foundation

enum GrafanaClientError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(status: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Grafana URL"
        case .invalidResponse:
            return "Unexpected response from Grafana"
        case let .httpError(status, body):
            return "HTTP \(status): \(body)"
        }
    }
}

struct GrafanaClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchAllAlerts(for instances: [GrafanaInstance]) async -> AlertsSnapshot {
        guard !instances.isEmpty else {
            return AlertsSnapshot(groups: [], totalCount: 0, lastUpdated: Date(), isLoading: false)
        }

        let groups = await withTaskGroup(of: InstanceAlertGroup.self) { group in
            for instance in instances {
                group.addTask {
                    do {
                        let alerts = try await self.fetchActiveAlerts(for: instance)
                        return InstanceAlertGroup(instance: instance, alerts: alerts, error: nil)
                    } catch {
                        return InstanceAlertGroup(
                            instance: instance,
                            alerts: [],
                            error: error.localizedDescription
                        )
                    }
                }
            }

            var results: [InstanceAlertGroup] = []
            for await result in group {
                results.append(result)
            }
            let order = Dictionary(uniqueKeysWithValues: instances.enumerated().map { ($1.id, $0) })
            return results.sorted {
                (order[$0.instance.id] ?? Int.max) < (order[$1.instance.id] ?? Int.max)
            }
        }

        let totalCount = groups.reduce(0) { $0 + $1.alerts.count }
        return AlertsSnapshot(
            groups: groups,
            totalCount: totalCount,
            lastUpdated: Date(),
            isLoading: false
        )
    }

    func testConnection(url: String, apiToken: String) async throws {
        let baseURL = ConfigStore.shared.normalizeURL(url)
        guard let endpoint = URL(string: "\(baseURL)/api/health") else {
            throw GrafanaClientError.invalidURL
        }

        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 10
        request.setValue("Bearer \(apiToken.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GrafanaClientError.invalidResponse
        }
        guard http.statusCode >= 200 && http.statusCode < 300 else {
            let body = String(data: data, encoding: .utf8) ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw GrafanaClientError.httpError(status: http.statusCode, body: body)
        }
    }

    private func fetchActiveAlerts(for instance: GrafanaInstance) async throws -> [NormalizedAlert] {
        let baseURL = ConfigStore.shared.normalizeURL(instance.url)
        guard var components = URLComponents(string: "\(baseURL)/api/alertmanager/grafana/api/v2/alerts") else {
            throw GrafanaClientError.invalidURL
        }

        components.queryItems = [
            URLQueryItem(name: "active", value: "true"),
            URLQueryItem(name: "silenced", value: "false"),
            URLQueryItem(name: "inhibited", value: "false"),
        ]

        guard let endpoint = components.url else {
            throw GrafanaClientError.invalidURL
        }

        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(instance.apiToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GrafanaClientError.invalidResponse
        }
        guard http.statusCode >= 200 && http.statusCode < 300 else {
            let body = String(data: data, encoding: .utf8) ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw GrafanaClientError.httpError(status: http.statusCode, body: body)
        }

        guard let rawAlerts = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw GrafanaClientError.invalidResponse
        }

        return rawAlerts.enumerated().compactMap { index, alert in
            normalizeAlert(alert, instance: instance, index: index)
        }.filter(\.isFiring)
    }

    private func normalizeAlert(_ alert: [String: Any], instance: GrafanaInstance, index: Int) -> NormalizedAlert? {
        let labels = alert["labels"] as? [String: Any] ?? [:]
        let annotations = alert["annotations"] as? [String: Any] ?? [:]
        let status = alert["status"] as? [String: Any] ?? [:]
        let state = (status["state"] as? String) ?? "active"
        let fingerprint = (labels["fingerprint"] as? String)
            ?? (labels["alertname"] as? String)
            ?? "\(instance.id.uuidString)-\(index)"

        let alertName = (labels["alertname"] as? String) ?? "Unnamed"
        let summary = (annotations["summary"] as? String)
            ?? (annotations["message"] as? String)
            ?? alertName

        let startsAt: Date?
        if let startsAtString = alert["startsAt"] as? String {
            startsAt = ISO8601DateFormatter().date(from: startsAtString)
        } else {
            startsAt = nil
        }

        let severity = (labels["severity"] as? String)
            ?? (labels["priority"] as? String)
            ?? "unknown"

        let isFiring = ["active", "firing"].contains(state.lowercased())

        return NormalizedAlert(
            id: "\(instance.id.uuidString)-\(fingerprint)",
            instanceId: instance.id,
            instanceName: instance.name,
            alertName: alertName,
            summary: summary,
            description: (annotations["description"] as? String) ?? "",
            severity: severity,
            state: state,
            startsAt: startsAt,
            isFiring: isFiring
        )
    }
}
