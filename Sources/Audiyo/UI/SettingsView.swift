import SwiftUI

enum SettingsTab: Hashable {
    case priorities
    case general
    case help
}

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        TabView(selection: Binding(get: { appState.settingsTab }, set: { appState.settingsTab = $0 })) {
            DevicesTab()
                .padding(20)
                .tabItem { Label("Device priorities", systemImage: "list.number") }
                .tag(SettingsTab.priorities)

            GeneralTab()
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)

            HelpTab()
                .tabItem { Label("Help", systemImage: "questionmark.circle") }
                .tag(SettingsTab.help)
        }
        .frame(minWidth: 760, idealWidth: 800, minHeight: 600, idealHeight: 640)
    }
}

private struct DevicesTab: View {
    @State private var direction: AudioDirection = .output

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AutomaticSwitchingView()
                .padding(12)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))

            Picker("Device list", selection: $direction) {
                Text("Sound output").tag(AudioDirection.output)
                Text("Microphone").tag(AudioDirection.input)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 360)
            .accessibilityLabel("Device list")

            PriorityPane(direction: direction)

            SettingsHelpText("Devices you add, reorder, remove from your list, or choose for system sounds stay saved. Other devices are forgotten after 7 days offline.")
        }
    }
}

private struct PriorityPane: View {
    @Environment(AppState.self) private var appState
    @State private var showsOtherDevices = false

    let direction: AudioDirection

    private var devices: [PriorityDevice] {
        appState.config.devices(for: direction)
    }

    private var preferredDevices: [PriorityDevice] {
        appState.config.preferredDevices(for: direction)
    }

    private var otherDevices: [PriorityDevice] {
        devices.filter { $0.mode == .never }
    }

    private var hasConnectedPreference: Bool {
        preferredDevices.contains { device in
            appState.endpoints.contains { $0.uid == device.uid && $0.direction == direction }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Switch to these devices, in this order")
                        .font(.headline)
                    Spacer()
                    Text("Drag to reorder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("Use #1 if connected, otherwise #2, and so on. Switch back when a higher choice reconnects.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            List {
                if preferredDevices.isEmpty {
                    VStack(spacing: 6) {
                        Text("Your list is empty")
                            .font(.headline)
                        Text("Expand Other devices below, then add devices in the order you want to use them.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(16)
                }

                ForEach(Array(preferredDevices.enumerated()), id: \.element.id) { entry in
                    deviceRow(entry.element, position: entry.offset + 1)
                }
                .onMove { source, destination in
                    appState.movePriority(direction: direction, from: source, to: destination)
                }
            }
            .listStyle(.inset)
            .frame(minHeight: 110)
            .scrollIndicators(.visible)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.quaternary, lineWidth: 1)
                    .allowsHitTesting(false)
            }

            if !preferredDevices.isEmpty && !hasConnectedPreference {
                SettingsHelpText("None of the devices in your list are connected.")
            }

            DisclosureGroup(isExpanded: $showsOtherDevices) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("New devices appear here. Add them to your list, or choose a connected device for now from the menu bar.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    List {
                        if otherDevices.isEmpty {
                            Text(devices.isEmpty ? "Connect a device to get started." : "No other devices. Newly detected devices will appear here.")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 10)
                        }
                        ForEach(otherDevices) { device in
                            deviceRow(device, position: nil)
                        }
                    }
                    .listStyle(.inset)
                    .frame(height: otherDevices.isEmpty ? 52 : min(132, CGFloat(otherDevices.count) * 64))
                    .scrollIndicators(.visible)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.quaternary, lineWidth: 1)
                            .allowsHitTesting(false)
                    }
                }
                .padding(.top, 6)
            } label: {
                HStack {
                    Text("Other devices (\(otherDevices.count))")
                        .font(.headline)
                    Spacer()
                    if showsOtherDevices && otherDevices.count > 2 {
                        Text("Scroll for more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func deviceRow(_ device: PriorityDevice, position: Int?) -> some View {
        let endpoint = appState.endpoints.first { $0.uid == device.uid && $0.direction == direction }
        let isDefault = endpoint != nil && device.uid == (direction == .input ? appState.defaultInputUID : appState.defaultOutputUID)
        let status = isDefault ? "In use" : endpoint == nil ? "Offline" : "Available"
        let needsIdentifier = devices.contains { $0.uid != device.uid && $0.name == device.name }
        let identifier = needsIdentifier ? " · …\(device.uid.suffix(8))" : ""

        return HStack(spacing: 12) {
            if let position {
                Text("\(position)")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26)
                    .accessibilityLabel("Priority \(position)")
                    .help("Drag to change priority, or use the More menu.")
            }

            if let endpoint {
                TransportIcon(endpoint: endpoint, highlighted: isDefault)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: direction == .input ? "mic.slash" : "speaker.slash")
                    .frame(width: 18)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(device.name)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .help("\(device.name)\nDevice ID: \(device.uid)")

                Text("\(status) · \(device.transport.rawValue)\(identifier)")
                    .font(.caption)
                    .foregroundStyle(isDefault ? Color.accentColor : Color.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
            .help(endpoint == nil ? retentionDescription(for: device) : "\(device.name)\nDevice ID: \(device.uid)")

            if position != nil {
                Button("Remove from list") {
                    appState.removeFromPriority(device, direction: direction)
                }
                .fixedSize()
                .help("Move to Other devices. You can still choose this device from the menu bar.")
                .accessibilityLabel("Remove \(device.name) from your priority list")
            } else {
                Button("Add to list") {
                    appState.addToPriority(device, direction: direction)
                }
                .fixedSize()
                .help("Add to the bottom of your priority list.")
                .accessibilityLabel("Add \(device.name) to your priority list")
            }

            Menu {
                if let position {
                    Button("Move up") { move(device, by: -1) }
                        .disabled(position == 1)
                    Button("Move down") { move(device, by: 1) }
                        .disabled(position == preferredDevices.count)
                    Divider()
                }
                Button("Forget device", role: .destructive) {
                    appState.forget(device, direction: direction)
                }
                .disabled(endpoint != nil)
                .help("Only offline devices can be forgotten. They are added again if they reconnect.")
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("More actions for \(device.name)")
            .help("Move this device or forget it when offline.")
        }
        .buttonStyle(.borderless)
        .padding(.vertical, 7)
        .accessibilityElement(children: .contain)
    }

    private func move(_ device: PriorityDevice, by offset: Int) {
        guard let index = preferredDevices.firstIndex(where: { $0.uid == device.uid }),
              preferredDevices.indices.contains(index + offset) else { return }
        appState.movePriority(
            direction: direction,
            from: IndexSet(integer: index),
            to: offset < 0 ? index - 1 : index + 2
        )
    }

    private func retentionDescription(for device: PriorityDevice) -> String {
        if device.isUserConfigured || (direction == .output && device.uid == appState.config.alertOutputUID) {
            return "Kept until forgotten"
        }
        if let lastSeen = device.lastSeen {
            return "Last seen \(lastSeen.formatted(date: .abbreviated, time: .omitted)) · Removed after 7 days unseen"
        }
        return "Removed after 7 days unseen"
    }
}

private struct GeneralTab: View {
    @Environment(AppState.self) private var appState

    private var outputs: [Endpoint] {
        appState.endpoints.filter { $0.direction == .output }
    }

    private var offlineAlertUID: String? {
        guard let uid = appState.config.alertOutputUID, !outputs.contains(where: { $0.uid == uid }) else { return nil }
        return uid
    }

    var body: some View {
        Form {
            Section("Audio") {
                Picker("Play system sounds through", selection: Binding(
                    get: { appState.config.alertOutputUID ?? "" },
                    set: { appState.setAlertOutput(uid: $0.isEmpty ? nil : $0) }
                )) {
                    Text("Use macOS setting").tag("")
                    ForEach(outputs) { output in
                        Text(outputName(uid: output.uid, name: output.name)).tag(output.uid)
                    }
                    if let uid = offlineAlertUID {
                        Text("\(outputName(uid: uid, name: appState.config.knownDevice(uid: uid, direction: .output)?.name ?? "Saved device")) (Offline)")
                            .tag(uid)
                    }
                }
                .help("A chosen device is used for system sounds while automatic switching is on. Use macOS setting leaves this choice to macOS.")

                if offlineAlertUID != nil {
                    SettingsHelpText("This device is offline. Automatic switching will use it for system sounds when it returns.")
                }
                if !appState.masterAuto && appState.config.alertOutputUID != nil {
                    SettingsHelpText("Turn on automatic switching in Device priorities to apply this choice.")
                }

                Toggle("Notify me when audio switches", isOn: Binding(
                    get: { appState.config.notificationsEnabled },
                    set: { appState.setNotificationsEnabled($0) }
                ))
            }

            Section("Startup") {
                Toggle("Open Audiyo at login", isOn: Binding(
                    get: { appState.launchAtLoginStatus == .enabled },
                    set: { appState.setLaunchAtLoginEnabled($0) }
                ))
                .disabled(!appState.launchAtLoginStatus.isAvailable)

                if case .requiresApproval = appState.launchAtLoginStatus {
                    SettingsHelpText("Approve Audiyo in System Settings to finish enabling launch at login.")
                }
                if case .unavailable(let message) = appState.launchAtLoginStatus {
                    SettingsHelpText(message)
                }
            }

            Section("Appearance") {
                Toggle("Show in the menu bar", isOn: Binding(
                    get: { appState.menuBarIconVisible },
                    set: { appState.setMenuBarIconVisible($0) }
                ))

                Toggle("Show in the Dock", isOn: Binding(
                    get: { appState.dockIconVisible },
                    set: { appState.setDockIconVisible($0) }
                ))

                SettingsHelpText("At least one stays visible so you can always open Audiyo again.")
            }
        }
        .formStyle(.grouped)
    }

    private func outputName(uid: String, name: String) -> String {
        let hasDuplicate = outputs.contains { $0.uid != uid && $0.name == name }
            || appState.config.output.contains { $0.uid != uid && $0.name == name }
        return hasDuplicate ? "\(name) · …\(uid.suffix(8))" : name
    }
}

private struct HelpTab: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Form {
            Section("Current audio") {
                LabeledContent("Sound output", value: name(for: appState.defaultOutputUID, direction: .output))
                LabeledContent("Microphone", value: name(for: appState.defaultInputUID, direction: .input))
                LabeledContent("System sounds", value: name(for: appState.defaultSystemOutputUID, direction: .output))
                LabeledContent("Last refresh", value: appState.lastRefresh?.formatted(date: .omitted, time: .standard) ?? "Loading…")
                Button("Refresh devices") { appState.refresh() }
            }

            if let error = appState.lastError {
                Section("Last error") {
                    Text(error)
                        .font(.caption)
                        .textSelection(.enabled)
                }
            }

            Section("Recent changes") {
                if appState.recentSwitches.isEmpty {
                    SettingsHelpText("Audio switches will appear here.")
                }
                ForEach(appState.recentSwitches) { change in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(change.name)
                            Group {
                                switch change.selector {
                                case .input: Text("Microphone")
                                case .output: Text("Sound output")
                                case .systemOutput: Text("System sounds")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(change.date, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Troubleshooting") {
                SettingsHelpText("Save a report with device details, preferences, and recent changes to share when asking for help.")
                Button {
                    appState.exportDiagnostics()
                } label: {
                    Label("Export diagnostics…", systemImage: "square.and.arrow.down")
                }
            }

            Section("About Audiyo") {
                LabeledContent("Version", value: "\(appState.appVersion) (\(appState.buildNumber))")
                LabeledContent("Location", value: appState.installStatusText)
                Text(appState.bundlePath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .formStyle(.grouped)
    }

    private func name(for uid: String?, direction: AudioDirection) -> String {
        guard let uid else { return "None" }
        return appState.endpoints.first { $0.uid == uid && $0.direction == direction }?.name
            ?? appState.config.knownDevice(uid: uid, direction: direction)?.name
            ?? "Unavailable device"
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
            .fixedSize(horizontal: false, vertical: true)
    }
}
