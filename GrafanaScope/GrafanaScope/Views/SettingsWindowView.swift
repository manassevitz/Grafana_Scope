import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case instances

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .instances: return "Instances"
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .instances: return "server.rack"
        }
    }
}

struct SettingsWindowView: View {
    @EnvironmentObject private var model: AppModel
    @State private var tab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $tab) {
                ForEach(SettingsTab.allCases) { item in
                    Label(item.title, systemImage: item.systemImage)
                        .tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            Group {
                switch tab {
                case .general:
                    GeneralSettingsPane()
                case .instances:
                    InstancesSettingsPane()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 560, minHeight: 420)
        .background(WindowFrontOnAppear())
    }
}

struct GeneralSettingsPane: View {
    @EnvironmentObject private var model: AppModel
    @State private var seconds: Int = 60
    @State private var savedMessage: String?

    var body: some View {
        Form {
            Section {
                Stepper(value: $seconds, in: 15...3600, step: 15) {
                    Text("Refresh every \(seconds) seconds")
                }
                .onChange(of: seconds) { newValue in
                    model.saveRefreshInterval(newValue)
                    savedMessage = "Saved"
                }

                if let savedMessage {
                    Text(savedMessage)
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            } header: {
                Text("Polling")
            } footer: {
                Text("Minimum interval is 15 seconds. Alerts are fetched from all enabled instances.")
            }

            Section {
                Toggle("Launch at login", isOn: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { model.setLaunchAtLogin($0) }
                ))

                if let launchAtLoginError = model.launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } footer: {
                Text("Uses the macOS login item API so Grafana Scope appears with the correct name and icon in System Settings.")
            }

            Section {
                Button("Refresh now") {
                    Task { await model.refreshAlerts() }
                }
            }

            Section {
                LabeledContent("Version", value: model.fullVersionString)
            } header: {
                Text("About")
            }
        }
        .formStyle(.grouped)
        .padding(.bottom, 8)
        .onAppear {
            seconds = model.config.refreshIntervalSeconds
            model.refreshLaunchAtLoginStatus()
        }
        .onChange(of: model.config.refreshIntervalSeconds) { newValue in
            seconds = newValue
        }
    }
}

struct InstancesSettingsPane: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedInstanceId: UUID?
    @State private var isAdding = false

    private var selectedIndex: Int? {
        guard let selectedInstanceId else { return nil }
        return model.config.instances.firstIndex(where: { $0.id == selectedInstanceId })
    }

    var body: some View {
        HSplitView {
            instanceList
                .frame(minWidth: 200, idealWidth: 230, maxWidth: 280)

            detailPane
                .frame(minWidth: 320)
        }
        .onChange(of: selectedInstanceId) { newValue in
            if newValue != nil {
                isAdding = false
            }
        }
        .onAppear {
            if selectedInstanceId == nil, !isAdding, let first = model.config.instances.first {
                selectedInstanceId = first.id
            }
        }
    }

    private var instanceList: some View {
        VStack(spacing: 0) {
            List(selection: $selectedInstanceId) {
                ForEach(model.config.instances) { instance in
                    InstanceListRow(
                        instance: instance,
                        isSelected: selectedInstanceId == instance.id
                    )
                    .tag(instance.id as UUID?)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isAdding = false
                        selectedInstanceId = instance.id
                    }
                }
                .onMove { from, to in
                    model.reorderInstances(fromOffsets: from, toOffset: to)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        moveSelectedInstance(by: -1)
                    } label: {
                        Image(systemName: "arrow.up")
                    }
                    .help("Move up")
                    .disabled(selectedIndex == nil || selectedIndex == 0)

                    Button {
                        moveSelectedInstance(by: 1)
                    } label: {
                        Image(systemName: "arrow.down")
                    }
                    .help("Move down")
                    .disabled(
                        selectedIndex == nil
                            || selectedIndex == model.config.instances.count - 1
                    )

                    Button {
                        isAdding = true
                        selectedInstanceId = nil
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("Add instance")
                }
            }
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if isAdding {
            InstanceEditorView(editId: nil) {
                isAdding = false
                if let last = model.config.instances.last {
                    selectedInstanceId = last.id
                }
            }
            .id("add")
        } else if let selectedInstanceId {
            InstanceEditorView(editId: selectedInstanceId) {
                self.selectedInstanceId = nil
            }
            .id(selectedInstanceId)
        } else {
            emptyDetail
        }
    }

    private var emptyDetail: some View {
        VStack(spacing: 8) {
            Image(systemName: "server.rack")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No instance selected")
                .font(.headline)
            Text("Select an instance from the list or add a new one.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func moveSelectedInstance(by offset: Int) {
        guard let id = selectedInstanceId else { return }
        if offset < 0 {
            model.moveInstanceUp(id: id)
        } else {
            model.moveInstanceDown(id: id)
        }
    }
}

private struct InstanceListRow: View {
    let instance: GrafanaInstance
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: instance.colorHex))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(instance.name)
                    .font(.body.weight(.medium))
                Text(instance.url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if !instance.enabled {
                Text("off")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct InstanceEditorView: View {
    @EnvironmentObject private var model: AppModel
    let editId: UUID?
    let onDone: () -> Void

    @State private var draft = GrafanaInstanceDraft()
    @State private var status: String = ""
    @State private var statusIsError = false
    @State private var isDirty = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(editId == nil ? "New instance" : draft.name.isEmpty ? "Instance" : draft.name)
                    .font(.headline)
                Spacer()
                if editId == nil {
                    Button("Cancel") { onDone() }
                }
                Button("Save") { save() }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!canSave)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            Form {
                Section {
                    TextField("Name", text: $draft.name)
                        .onChange(of: draft.name) { _ in isDirty = true }
                    TextField("URL", text: $draft.url)
                        .onChange(of: draft.url) { _ in isDirty = true }
                    SecureField("API Token", text: $draft.apiToken)
                        .onChange(of: draft.apiToken) { _ in isDirty = true }
                    Toggle("Enabled", isOn: $draft.enabled)
                        .onChange(of: draft.enabled) { _ in isDirty = true }
                } header: {
                    Text("Connection")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        if !status.isEmpty {
                            Text(status)
                                .foregroundStyle(statusIsError ? .red : .green)
                        }
                        Button("Verify connection") {
                            testConnection()
                        }
                        .buttonStyle(.link)
                        .disabled(draft.url.isEmpty || draft.apiToken.isEmpty)
                    }
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: 8), count: 8)) {
                        ForEach(InstanceColors.palette, id: \.self) { color in
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: 22, height: 22)
                                .overlay {
                                    if draft.colorHex.caseInsensitiveCompare(color) == .orderedSame {
                                        Circle().stroke(Color.primary, lineWidth: 2)
                                    }
                                }
                                .onTapGesture {
                                    draft.colorHex = color
                                    isDirty = true
                                }
                        }
                    }
                    .padding(.vertical, 4)

                    HStack(alignment: .center) {
                        Text("Custom color")
                        Spacer(minLength: 12)
                        PopoverColorWell(hex: Binding(
                            get: { draft.colorHex },
                            set: { draft.colorHex = $0 }
                        )) {
                            isDirty = true
                        }
                        .frame(width: 44, height: 26)
                    }
                    .padding(.top, 4)
                }

                if editId != nil {
                    Section {
                        Button("Delete instance", role: .destructive) {
                            if let editId {
                                model.removeInstance(id: editId)
                                onDone()
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .onAppear(perform: loadDraft)
        .onChange(of: editId) { _ in loadDraft() }
    }

    private var canSave: Bool {
        !draft.name.isEmpty && !draft.url.isEmpty && !draft.apiToken.isEmpty && (isDirty || editId == nil)
    }

    private func loadDraft() {
        status = ""
        statusIsError = false

        guard let editId,
              let instance = model.config.instances.first(where: { $0.id == editId }) else {
            draft = GrafanaInstanceDraft()
            isDirty = false
            return
        }
        draft = GrafanaInstanceDraft(
            name: instance.name,
            url: instance.url,
            apiToken: instance.apiToken,
            enabled: instance.enabled,
            colorHex: instance.colorHex
        )
        isDirty = false
    }

    private func testConnection() {
        Task {
            status = "Verifying…"
            statusIsError = false
            let result = await model.testConnection(url: draft.url, apiToken: draft.apiToken)
            switch result {
            case .success:
                status = "Connection OK"
            case let .failure(error):
                status = error.localizedDescription
                statusIsError = true
            }
        }
    }

    private func save() {
        if let editId {
            model.updateInstance(id: editId, draft: draft)
            isDirty = false
            status = "Saved"
            statusIsError = false
        } else {
            model.addInstance(draft)
            onDone()
        }
    }
}
