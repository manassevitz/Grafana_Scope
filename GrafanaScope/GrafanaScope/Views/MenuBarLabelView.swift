import SwiftUI

struct MenuBarLabelView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 2) {
            if let image = model.menuBarIcon() {
                Image(nsImage: image)
            }
            if !model.menuBarTitle.isEmpty {
                Text(model.menuBarTitle)
                    .font(.system(size: 12, weight: .semibold))
            }
        }
        .contextMenu {
            MenuBarCommands()
        }
    }
}
