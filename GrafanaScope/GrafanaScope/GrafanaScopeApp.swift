import SwiftUI

@main
struct GrafanaScopeApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        MenuBarExtra {
            AlertsView()
                .environmentObject(appModel)
        } label: {
            MenuBarLabelView()
                .environmentObject(appModel)
        }
        .menuBarExtraStyle(.window)

        Window("Settings", id: "settings") {
            SettingsWindowView()
                .environmentObject(appModel)
        }
        .defaultSize(width: 720, height: 460)
        .windowResizability(.contentSize)

        Window("About Grafana Scope", id: "about") {
            AboutView()
                .environmentObject(appModel)
        }
        .defaultSize(width: 320, height: 280)
        .windowResizability(.contentSize)
    }
}

struct MenuBarCommands: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Refresh") {
            Task { await model.refreshAlerts() }
        }

        Divider()

        Text("Version \(model.fullVersionString)")
            .foregroundStyle(.secondary)

        Button("About Grafana Scope") {
            AppWindows.open(openWindow, id: "about")
        }

        Button("Settings…") {
            AppWindows.open(openWindow, id: "settings")
        }

        Divider()

        Button("Quit Grafana Scope") {
            model.quit()
        }
    }
}
