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
                SettingsHelpText("Current defaults are what macOS is using now. Audiyo compares these against your priority lists when Auto is on.")
                LabeledContent("Auto", value: appState.masterAuto ? "On" : "Off")
                    .help("When Auto is on, Audiyo can restore your preferred input, output, and alert routing after device changes.")
                LabeledContent("Input", value: name(for: appState.defaultInputUID, direction: .input))
                    .help("The current macOS default input device.")
                LabeledContent("Output", value: name(for: appState.defaultOutputUID, direction: .output))
                    .help("The current macOS default output device.")
                LabeledContent("Alerts", value: name(for: appState.defaultSystemOutputUID, direction: .output))
                    .help("The current macOS alert and system sound output device.")
                LabeledContent("Last refresh", value: appState.lastRefresh?.formatted(date: .omitted, time: .standard) ?? "Loading")
                    .help("The last time Audiyo received a CoreAudio device snapshot.")
            }

            Section("Install") {
                SettingsHelpText("Launch at Login is available after Audiyo is installed in /Applications and opened from there.")
                LabeledContent("Location", value: appState.installStatusText)
                    .help("Audiyo checks this path because macOS login item registration is only predictable from the installed app.")
                Text(appState.bundlePath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .help("The app bundle path Audiyo is running from.")
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
        VStack(alignment: .leading, spacing: 14) {
            SettingsCallout(
                systemImage: "arrow.up.arrow.down",
                title: "Priority order",
                message: "Drag devices up or down to reorder them. Audiyo tries higher Auto devices first; Never devices stay known but are not selected automatically."
            )

            HStack(spacing: 18) {
                PriorityPane(direction: .output, title: "Output")
                Divider()
                PriorityPane(direction: .input, title: "Input")
            }
        }
    }
}

private struct PriorityPane: View {
    @Environment(AppState.self) private var appState

    let direction: AudioDirection
    let title: String

    private var devices: [PriorityDevice] {
        appState.config.devices(for: direction)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.title3.weight(.semibold))
                Spacer()
                Label("Drag to reorder", systemImage: "line.3.horizontal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("Drag rows up or down to change the \(title.lowercased()) priority order.")
            }

            Text("Top devices win first when Auto is on. Use Mode to allow automatic selection or keep a device out of automatic routing.")
                .font(.caption)
                .foregroundStyle(.secondary)

            List {
                if devices.isEmpty {
                    Text("Known \(title.lowercased()) devices appear here after Audiyo sees them.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(Array(devices.enumerated()), id: \.element.id) { entry in
                    priorityRow(entry.element, position: entry.offset + 1)
                        .contextMenu {
                            Button("Forget", role: .destructive) {
                                appState.forget(entry.element, direction: direction)
                            }
                            .help("Remove this remembered device from Audiyo's priority list.")
                        }
                }
                .onMove { source, destination in
                    appState.movePriority(direction: direction, from: source, to: destination)
                }
            }
        }
    }

    private func priorityRow(_ device: PriorityDevice, position: Int) -> some View {
        let endpoint = appState.endpoints.first { $0.uid == device.uid && $0.direction == direction }
        let isDefault = device.uid == (direction == .input ? appState.defaultInputUID : appState.defaultOutputUID)

        return HStack(spacing: 8) {
            Text("\(position)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
                .help("Priority \(position). Lower numbers are tried first.")

            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .help("Drag this row to reorder the priority list.")

            if let endpoint {
                TransportIcon(endpoint: endpoint, highlighted: isDefault)
            } else {
                Image(systemName: direction == .input ? "mic.slash" : "speaker.slash")
                    .frame(width: 18)
                    .foregroundStyle(.secondary)
                    .help("Audiyo remembers this device, but it is not currently connected.")
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(device.name)
                        .lineLimit(1)
                    if isDefault {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                            .help("This is the current macOS default \(direction == .input ? "input" : "output").")
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
            .help("Auto lets Audiyo select this device when it is the highest available priority. Never keeps the device remembered but blocks automatic selection.")
            .accessibilityLabel("Mode for \(device.name)")
        }
        .help("Drag to reorder. Higher rows have higher priority.")
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
                SettingsHelpText("Automation controls whether Audiyo corrects macOS defaults after devices appear, disappear, or change state.")
                Toggle("Auto", isOn: Binding(
                    get: { appState.masterAuto },
                    set: { appState.setAutoEnabled($0) }
                ))
                .help("Turn this off to stop Audiyo from automatically changing input, output, or alert defaults.")

                Toggle("New Bluetooth inputs use Never", isOn: Binding(
                    get: { appState.config.newBluetoothInputsNever },
                    set: { appState.setNewBluetoothInputsNever($0) }
                ))
                .help("When enabled, newly discovered Bluetooth microphones start in Never mode so headset mics do not become default automatically.")
            }

            Section("System") {
                SettingsHelpText("System options control notifications, alert routing, and whether Audiyo starts automatically after login.")
                Toggle("Notifications", isOn: Binding(
                    get: { appState.config.notificationsEnabled },
                    set: { appState.setNotificationsEnabled($0) }
                ))
                .help("Allow Audiyo to notify you when it changes audio routing or needs attention.")

                Picker("Alert device", selection: Binding(
                    get: { appState.config.alertOutputUID ?? "" },
                    set: { appState.setAlertOutput(uid: $0.isEmpty ? nil : $0) }
                )) {
                    Text("Follow output").tag("")
                    ForEach(outputs) { output in
                        Text(output.name).tag(output.uid)
                    }
                }
                .help("Choose where macOS system alerts play. Follow output keeps alerts aligned with the main output device.")

                Toggle("Launch at Login", isOn: Binding(
                    get: { appState.launchAtLoginStatus == .enabled },
                    set: { appState.setLaunchAtLoginEnabled($0) }
                ))
                .disabled(!appState.launchAtLoginStatus.isAvailable)
                .help("Start Audiyo automatically as a menu-bar utility when you log in. This is available after installing Audiyo in /Applications.")

                launchAtLoginMessage
            }

            Section("Visibility") {
                SettingsHelpText("Choose where Audiyo appears. Audiyo keeps at least one control surface visible so you can get back to Settings.")

                Toggle("Show menu-bar icon", isOn: Binding(
                    get: { appState.menuBarIconVisible },
                    set: { appState.setMenuBarIconVisible($0) }
                ))
                .help("Show Audiyo in the top-right macOS menu bar. If you turn this off while the Dock icon is hidden, Audiyo turns the Dock icon on.")

                Toggle("Show Dock icon", isOn: Binding(
                    get: { appState.dockIconVisible },
                    set: { appState.setDockIconVisible($0) }
                ))
                .help("Show Audiyo as a normal macOS app in the Dock and app switcher. If you turn this off while the menu-bar icon is hidden, Audiyo turns the menu-bar icon on.")
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
                SettingsHelpText("Use this information when checking which build is installed or when sharing diagnostics.")
                LabeledContent("Version", value: "\(appState.appVersion) (\(appState.buildNumber))")
                    .help("The marketing version and build number from the app bundle.")
                LabeledContent("Endpoints", value: "\(appState.endpoints.count)")
                    .help("The number of CoreAudio input and output endpoints Audiyo can currently see.")
                LabeledContent("Recent switches", value: "\(appState.recentSwitches.count)")
                    .help("How many recent routing changes Audiyo has recorded in this session.")
            }

            Section("Diagnostics") {
                SettingsHelpText("Diagnostics are saved only when you export them. They include app state, device summaries, recent switches, and the last error.")
                Button {
                    appState.exportDiagnostics()
                } label: {
                    Label("Export Diagnostics...", systemImage: "square.and.arrow.down")
                }
                .help("Save a text report you can inspect or share when troubleshooting.")
            }
        }
        .formStyle(.grouped)
    }
}

private struct SettingsHelpText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

private struct SettingsCallout: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .help(message)
    }
}
