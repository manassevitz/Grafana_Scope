import SwiftUI

struct AboutView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 16) {
            if let icon = model.appIcon() {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 64, height: 64)
            } else {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 4) {
                Text("Grafana Scope")
                    .font(.title2.weight(.semibold))
                Text("Version \(model.fullVersionString)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("Monitor active Grafana Unified Alerting alerts from the macOS menu bar.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WindowFrontOnAppear())
    }
}
