import Foundation

final class ConfigStore {
    static let shared = ConfigStore()

    private let fileManager = FileManager.default
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
    private let decoder = JSONDecoder()

    private var configURL: URL {
        appSupportDirectory.appendingPathComponent("config.json")
    }

    private var appSupportDirectory: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Grafana_Scope", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func load() -> AppConfig {
        if let config = loadFromDisk() {
            return config
        }
        if let migrated = migrateLegacyConfig() {
            save(migrated)
            return migrated
        }
        return .default
    }

    func save(_ config: AppConfig) {
        let normalized = normalize(config)
        do {
            let data = try encoder.encode(normalized)
            try data.write(to: configURL, options: .atomic)
        } catch {
            NSLog("GrafanaScope: failed to save config: \(error.localizedDescription)")
        }
    }

    func normalize(_ config: AppConfig) -> AppConfig {
        var copy = config
        copy.instances = config.instances.enumerated().map { index, instance in
            var item = instance
            item.name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            item.url = normalizeURL(item.url)
            item.apiToken = item.apiToken.trimmingCharacters(in: .whitespacesAndNewlines)
            if item.colorHex.isEmpty {
                item.colorHex = InstanceColors.defaultColor(for: index)
            }
            return item
        }
        copy.refreshIntervalSeconds = max(15, min(3600, copy.refreshIntervalSeconds))
        return copy
    }

    func normalizeURL(_ url: String) -> String {
        var value = url.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasSuffix("/") {
            value.removeLast()
        }
        return value
    }

    private func loadFromDisk() -> AppConfig? {
        guard fileManager.fileExists(atPath: configURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: configURL)
            let config = try decoder.decode(AppConfig.self, from: data)
            return normalize(config)
        } catch {
            NSLog("GrafanaScope: failed to load config: \(error.localizedDescription)")
            return nil
        }
    }

    private func migrateLegacyConfig() -> AppConfig? {
        let home = fileManager.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent("Library/Application Support/grafana-menubar/grafana-menubar.json"),
            home.appendingPathComponent("Library/Application Support/Grafana_Scope/grafana-menubar.json"),
            home.appendingPathComponent("Library/Application Support/Electron/grafana-menubar.json"),
        ]

        for url in candidates where fileManager.fileExists(atPath: url.path) {
            if let config = decodeLegacy(at: url) {
                return config
            }
        }
        return nil
    }

    private func decodeLegacy(at url: URL) -> AppConfig? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let interval = json["refreshIntervalSeconds"] as? Int ?? 60
        guard let rawInstances = json["instances"] as? [[String: Any]] else {
            return AppConfig(instances: [], refreshIntervalSeconds: interval)
        }

        let instances: [GrafanaInstance] = rawInstances.compactMap { item in
            guard let name = item["name"] as? String,
                  let url = item["url"] as? String,
                  let token = item["apiToken"] as? String else {
                return nil
            }

            let idString = item["id"] as? String
            let id = idString.flatMap(UUID.init(uuidString:)) ?? UUID()
            return GrafanaInstance(
                id: id,
                name: name,
                url: url,
                apiToken: token,
                enabled: item["enabled"] as? Bool ?? true,
                colorHex: item["color"] as? String ?? InstanceColors.defaultColor(for: 0)
            )
        }

        return normalize(AppConfig(instances: instances, refreshIntervalSeconds: interval))
    }
}
