import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView {
            OverviewTab()
                .padding()
                .tabItem { Label("Overview", systemImage: "gauge") }

            DevicesTab()
                .padding()
                .tabItem { Label("Devices", systemImage: "speaker.wave.2") }

            BehaviorTab()
                .padding()
                .tabItem { Label("Behavior", systemImage: "switch.2") }

            SupportTab()
                .padding()
                .tabItem { Label("Support", systemImage: "info.circle") }
        }
        .frame(width: 680, height: 520)
    }
}

private struct OverviewTab: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Form {
            Section("Status") {
                LabeledContent("Auto", value: appState.masterAuto ? "On" : "Off")
                LabeledContent("Input", value: name(for: appState.defaultInputUID, direction: .input))
                LabeledContent("Output", value: name(for: appState.defaultOutputUID, direction: .output))
                LabeledContent("Alerts", value: name(for: appState.defaultSystemOutputUID, direction: .output))
                LabeledContent("Last refresh", value: appState.lastRefresh?.formatted(date: .omitted, time: .standard) ?? "Loading")
            }

            Section("Install") {
                LabeledContent("Location", value: appState.installStatusText)
                Text(appState.bundlePath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                if case .unavailable(let message) = appState.launchAtLoginStatus {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let error = appState.lastError {
                Section("Last Error") {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func name(for uid: String?, direction: AudioDirection) -> String {
        guard let uid else { return "None" }
        return appState.endpoints.first { $0.uid == uid && $0.direction == direction }?.name ?? uid
    }
}

private struct DevicesTab: View {
    var body: some View {
        HStack(spacing: 18) {
            PriorityPane(direction: .output, title: "Output")
            Divider()
            PriorityPane(direction: .input, title: "Input")
        }
    }
}

private struct PriorityPane: View {
    @Environment(AppState.self) private var appState

    let direction: AudioDirection
    let title: String

    private var devices: [PriorityDevice] {
        appState.config.priority(for: direction).compactMap { uid in
            appState.config.knownDevice(uid: uid, direction: direction)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.semibold))

            List {
                ForEach(devices) { device in
                    priorityRow(device)
                        .contextMenu {
                            Button("Forget", role: .destructive) {
                                appState.forget(device, direction: direction)
                            }
                        }
                }
                .onMove { source, destination in
                    appState.movePriority(direction: direction, from: source, to: destination)
                }
            }
        }
    }

    private func priorityRow(_ device: PriorityDevice) -> some View {
        let endpoint = appState.endpoints.first { $0.uid == device.uid && $0.direction == direction }
        let isDefault = device.uid == (direction == .input ? appState.defaultInputUID : appState.defaultOutputUID)

        return HStack(spacing: 8) {
            if let endpoint {
                TransportIcon(endpoint: endpoint, highlighted: isDefault)
            } else {
                Image(systemName: direction == .input ? "mic.slash" : "speaker.slash")
                    .frame(width: 18)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(device.name)
                        .lineLimit(1)
                    if isDefault {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                    if endpoint == nil {
                        Text("offline")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text("\(device.transport.rawValue) · \(device.uid.suffix(8))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Picker("Mode", selection: modeBinding(for: device)) {
                Text("Auto").tag(DeviceMode.automatic)
                Text("Never").tag(DeviceMode.never)
            }
            .labelsHidden()
            .frame(width: 96)
        }
    }

    private func modeBinding(for device: PriorityDevice) -> Binding<DeviceMode> {
        Binding {
            appState.config.knownDevice(uid: device.uid, direction: direction)?.mode ?? .automatic
        } set: { mode in
            if let endpoint = appState.endpoints.first(where: { $0.uid == device.uid && $0.direction == direction }) {
                appState.setMode(mode, for: endpoint)
            } else {
                var updated = device
                updated.mode = mode
                appState.setKnownDevice(updated, direction: direction)
            }
        }
    }
}

private struct BehaviorTab: View {
    @Environment(AppState.self) private var appState

    private var outputs: [Endpoint] {
        appState.endpoints.filter { $0.direction == .output }
    }

    var body: some View {
        Form {
            Section("Automation") {
                Toggle("Auto", isOn: Binding(
                    get: { appState.masterAuto },
                    set: { appState.setAutoEnabled($0) }
                ))

                Toggle("New Bluetooth inputs use Never", isOn: Binding(
                    get: { appState.config.newBluetoothInputsNever },
                    set: { appState.setNewBluetoothInputsNever($0) }
                ))
            }

            Section("System") {
                Toggle("Notifications", isOn: Binding(
                    get: { appState.config.notificationsEnabled },
                    set: { appState.setNotificationsEnabled($0) }
                ))

                Picker("Alert device", selection: Binding(
                    get: { appState.config.alertOutputUID ?? "" },
                    set: { appState.setAlertOutput(uid: $0.isEmpty ? nil : $0) }
                )) {
                    Text("Follow output").tag("")
                    ForEach(outputs) { output in
                        Text(output.name).tag(output.uid)
                    }
                }

                Toggle("Launch at Login", isOn: Binding(
                    get: { appState.launchAtLoginStatus == .enabled },
                    set: { appState.setLaunchAtLoginEnabled($0) }
                ))
                .disabled(!appState.launchAtLoginStatus.isAvailable)

                launchAtLoginMessage
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private var launchAtLoginMessage: some View {
        if case .requiresApproval = appState.launchAtLoginStatus {
            Text("Approve Audiyo in System Settings to finish enabling launch at login.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        if case .unavailable(let message) = appState.launchAtLoginStatus {
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SupportTab: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Form {
            Section("Audiyo") {
                LabeledContent("Version", value: "\(appState.appVersion) (\(appState.buildNumber))")
                LabeledContent("Endpoints", value: "\(appState.endpoints.count)")
                LabeledContent("Recent switches", value: "\(appState.recentSwitches.count)")
            }

            Section("Diagnostics") {
                Button {
                    appState.exportDiagnostics()
                } label: {
                    Label("Export Diagnostics...", systemImage: "square.and.arrow.down")
                }
            }
        }
        .formStyle(.grouped)
    }
}
