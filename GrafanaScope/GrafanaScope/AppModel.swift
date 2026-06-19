import AppKit
import Combine
import Foundation
import ServiceManagement
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var snapshot: AlertsSnapshot = .empty
    @Published var config: AppConfig
    @Published var collapsedGroups: [UUID: Bool] = [:]
    @Published private(set) var launchAtLoginEnabled = false
    @Published var launchAtLoginError: String?

    private let configStore = ConfigStore.shared
    private let client = GrafanaClient()
    private var pollTask: Task<Void, Never>?

    var menuBarTitle: String {
        if snapshot.isLoading && snapshot.totalCount == 0 {
            return " …"
        }
        if snapshot.totalCount > 0 {
            return " \(snapshot.totalCount)"
        }
        return ""
    }

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.3.0"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var fullVersionString: String {
        "\(appVersion) (\(buildNumber))"
    }

    func appIcon() -> NSImage? {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return menuBarIcon()
    }

    init() {
        Self.runCommandLineToolIfNeeded()

        config = configStore.load()
        refreshLaunchAtLoginStatus()
        startPolling()
        Task { await refreshAlerts() }
    }

    static func runCommandLineToolIfNeeded() {
        let args = CommandLine.arguments
        if args.contains("--register-login") {
            exit(registerLaunchAtLogin())
        }
        if args.contains("--unregister-login") {
            exit(unregisterLaunchAtLogin())
        }
    }

    @discardableResult
    static func registerLaunchAtLogin() -> Int32 {
        do {
            try SMAppService.mainApp.register()
            return 0
        } catch {
            fputs("Failed to register login item: \(error.localizedDescription)\n", stderr)
            return 1
        }
    }

    @discardableResult
    static func unregisterLaunchAtLogin() -> Int32 {
        do {
            try SMAppService.mainApp.unregister()
            return 0
        } catch {
            fputs("Failed to unregister login item: \(error.localizedDescription)\n", stderr)
            return 1
        }
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refreshLaunchAtLoginStatus()
        } catch {
            launchAtLoginError = error.localizedDescription
            refreshLaunchAtLoginStatus()
        }
    }

    deinit {
        pollTask?.cancel()
    }

    func refreshAlerts() async {
        snapshot.isLoading = true
        let enabled = config.instances.filter(\.enabled)
        let result = await client.fetchAllAlerts(for: enabled)
        snapshot = AlertsSnapshot(
            groups: result.groups,
            totalCount: result.totalCount,
            lastUpdated: result.lastUpdated,
            isLoading: false
        )
    }

    func saveConfig(_ newConfig: AppConfig) {
        config = configStore.normalize(newConfig)
        configStore.save(config)
        restartPolling()
        Task { await refreshAlerts() }
    }

    func saveRefreshInterval(_ seconds: Int) {
        var copy = config
        copy.refreshIntervalSeconds = seconds
        saveConfig(copy)
    }

    func addInstance(_ draft: GrafanaInstanceDraft) {
        var copy = config
        let instance = GrafanaInstance(
            id: UUID(),
            name: draft.name,
            url: draft.url,
            apiToken: draft.apiToken,
            enabled: draft.enabled,
            colorHex: draft.colorHex.isEmpty
                ? InstanceColors.defaultColor(for: copy.instances.count)
                : draft.colorHex
        )
        copy.instances.append(instance)
        saveConfig(copy)
    }

    func updateInstance(id: UUID, draft: GrafanaInstanceDraft) {
        guard let index = config.instances.firstIndex(where: { $0.id == id }) else { return }
        var copy = config
        copy.instances[index].name = draft.name
        copy.instances[index].url = draft.url
        copy.instances[index].apiToken = draft.apiToken
        copy.instances[index].enabled = draft.enabled
        copy.instances[index].colorHex = draft.colorHex
        saveConfig(copy)
    }

    func removeInstance(id: UUID) {
        var copy = config
        copy.instances.removeAll { $0.id == id }
        collapsedGroups[id] = nil
        saveConfig(copy)
    }

    func reorderInstances(fromOffsets: IndexSet, toOffset: Int) {
        var copy = config
        copy.instances.move(fromOffsets: fromOffsets, toOffset: toOffset)
        saveConfig(copy)
    }

    func moveInstanceUp(id: UUID) {
        guard let index = config.instances.firstIndex(where: { $0.id == id }), index > 0 else { return }
        var copy = config
        copy.instances.swapAt(index, index - 1)
        saveConfig(copy)
    }

    func moveInstanceDown(id: UUID) {
        guard let index = config.instances.firstIndex(where: { $0.id == id }),
              index < config.instances.count - 1 else { return }
        var copy = config
        copy.instances.swapAt(index, index + 1)
        saveConfig(copy)
    }

    func testConnection(url: String, apiToken: String) async -> Result<Void, Error> {
        do {
            try await client.testConnection(url: url, apiToken: apiToken)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func isGroupCollapsed(_ group: InstanceAlertGroup) -> Bool {
        if let value = collapsedGroups[group.id] {
            return value
        }
        return group.alerts.isEmpty && group.error == nil
    }

    func toggleGroup(_ group: InstanceAlertGroup) {
        collapsedGroups[group.id] = !isGroupCollapsed(group)
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    func menuBarIcon() -> NSImage? {
        guard let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Grafana Scope")
        }
        image.isTemplate = true
        return image
    }

    private func restartPolling() {
        pollTask?.cancel()
        startPolling()
    }

    private func startPolling() {
        let interval = max(15, config.refreshIntervalSeconds)
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
                guard !Task.isCancelled else { break }
                await self?.refreshAlerts()
            }
        }
    }
}

struct GrafanaInstanceDraft: Equatable {
    var name: String = ""
    var url: String = ""
    var apiToken: String = ""
    var enabled: Bool = true
    var colorHex: String = InstanceColors.palette[0]
}
