import SwiftUI

struct MenuView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openSettings) private var openSettings

    private var outputs: [Endpoint] { connectedDevices(for: .output) }
    private var inputs: [Endpoint] { connectedDevices(for: .input) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Audiyo", systemImage: "speaker.wave.2")
                .font(.headline)

            AutomaticSwitchingView()

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                DeviceSection(
                    title: "Sound output",
                    endpoints: outputs,
                    defaultUID: appState.defaultOutputUID,
                    systemDefaultUID: appState.defaultSystemOutputUID,
                    onSelect: select
                )

                if outputs.contains(where: { $0.uid == appState.defaultOutputUID }) {
                    VolumeSlider(
                        title: "Output volume",
                        volume: Binding(get: { appState.outputVolume }, set: { appState.setOutputVolume($0) }),
                        isMuted: Binding(get: { appState.outputMuted }, set: { appState.setOutputMuted($0) }),
                        isVolumeEnabled: appState.outputVolumeEnabled,
                        isMuteEnabled: appState.outputMuteEnabled,
                        onVolumeEditingChanged: { appState.setOutputVolumeEditing($0) }
                    )
                }

                Divider()

                DeviceSection(
                    title: "Microphone",
                    endpoints: inputs,
                    defaultUID: appState.defaultInputUID,
                    systemDefaultUID: nil,
                    onSelect: select
                )
            }

            Text("Choose a device for now. Set lasting preferences in Device priorities.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            HStack {
                Button("Device priorities…") {
                    appState.settingsTab = .priorities
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                    dismiss()
                }
                Spacer()
                Button("Refresh") {
                    appState.refresh()
                }
                .help("Check for connected audio devices again.")
                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .help("Quit Audiyo and stop automatic switching.")
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
    }

    private func select(_ endpoint: Endpoint) {
        appState.userSelect(endpoint)
        dismiss()
    }

    private func connectedDevices(for direction: AudioDirection) -> [Endpoint] {
        let priority = appState.config.priority(for: direction)
        let currentUID = direction == .input ? appState.defaultInputUID : appState.defaultOutputUID
        return appState.endpoints.filter { $0.direction == direction }.sorted {
            if ($0.uid == currentUID) != ($1.uid == currentUID) {
                return $0.uid == currentUID
            }
            let first = priority.firstIndex(of: $0.uid) ?? Int.max
            let second = priority.firstIndex(of: $1.uid) ?? Int.max
            return first == second ? $0 < $1 : first < second
        }
    }
}

struct AutomaticSwitchingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Automatic switching", isOn: Binding(
                get: { appState.masterAuto },
                set: { appState.setAutoEnabled($0) }
            ))
            .toggleStyle(.switch)
            .help("Let Audiyo choose your highest-priority available devices.")

            Text(!appState.masterAuto
                 ? "Paused. Audiyo will not switch devices automatically."
                 : appState.hasManualSelection
                 ? "Your menu-bar choice takes priority when connected."
                 : "Follows your numbered lists in Device priorities.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if appState.hasManualSelection {
                HStack {
                    Label("Temporary selection", systemImage: "hand.point.up.left")
                        .font(.caption)
                        .help("Your menu-bar selection takes priority until you use your list again or quit Audiyo.")
                    Spacer()
                    Button("Use my list again") {
                        appState.resumePriorities()
                    }
                    .controlSize(.small)
                    .help("End the temporary selection and follow your numbered lists again.")
                }
            }

            if appState.lastRefresh == nil {
                Label("Finding audio devices…", systemImage: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if appState.lastError != nil {
                HStack {
                    Label("Something needs attention.", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Spacer()
                    Button("Details…") {
                        appState.settingsTab = .help
                        NSApp.activate(ignoringOtherApps: true)
                        openSettings()
                    }
                    .controlSize(.small)
                }
            }

            if case .suspended(let until) = appState.badgeState, until > Date() {
                Label("Repeated audio changes detected. Switching is paused briefly.", systemImage: "pause.circle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if appState.hasHFPWarning {
                Label("Bluetooth call audio is active. Headset microphone use can reduce sound quality.", systemImage: "headphones")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct DeviceSection: View {
    let title: String
    let endpoints: [Endpoint]
    let defaultUID: String?
    let systemDefaultUID: String?
    let onSelect: (Endpoint) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if endpoints.count > 3 {
                    Text("\(endpoints.count) devices · Scroll for more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if endpoints.isEmpty {
                Text("No devices available. Connect a device, then choose Refresh.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if endpoints.count > 3 {
                ScrollView {
                    deviceRows
                        .padding(.trailing, 8)
                }
                .frame(height: 148)
                .scrollIndicators(.visible)
            } else {
                deviceRows
            }
        }
    }

    private var deviceRows: some View {
        VStack(spacing: 6) {
            ForEach(endpoints) { endpoint in
                DeviceRow(
                    endpoint: endpoint,
                    isDefault: endpoint.uid == defaultUID,
                    isSystemDefault: endpoint.uid == systemDefaultUID,
                    showsIdentifier: endpoints.filter { $0.name == endpoint.name }.count > 1,
                    action: { onSelect(endpoint) }
                )
            }
        }
    }
}
