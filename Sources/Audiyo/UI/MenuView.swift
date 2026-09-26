import SwiftUI

struct MenuView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openSettings) private var openSettings

    private var outputs: [Endpoint] {
        appState.config.connectedPriorityEndpoints(for: .output, in: appState.endpoints)
    }
    private var inputs: [Endpoint] {
        appState.config.connectedPriorityEndpoints(for: .input, in: appState.endpoints)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Audiyo", systemImage: "speaker.wave.2")
                    .font(.headline)
                Spacer()
                Text("Priority devices")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            AutomaticSwitchingView()
                .controlSize(.small)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                DeviceSection(
                    title: "Sound output",
                    endpoints: outputs,
                    hasPriorities: !appState.config.priority(for: .output).isEmpty,
                    defaultUID: appState.defaultOutputUID,
                    systemDefaultUID: appState.defaultSystemOutputUID,
                    onSelect: appState.userSelect
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
                    hasPriorities: !appState.config.priority(for: .input).isEmpty,
                    defaultUID: appState.defaultInputUID,
                    systemDefaultUID: nil,
                    onSelect: appState.userSelect
                )
            }

            Divider()

            HStack {
                Button("Device priorities…") {
                    appState.settingsTab = .priorities
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                    dismiss()
                }
                .help("Choose which devices appear here and set their priority order.")
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
        .padding(12)
        .frame(width: 420)
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
    let hasPriorities: Bool
    let defaultUID: String?
    let systemDefaultUID: String?
    let onSelect: (Endpoint) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if endpoints.count > 6 {
                    Text("\(endpoints.count) devices · Scroll for more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if endpoints.isEmpty {
                Text(hasPriorities
                     ? "None of your priority devices are connected."
                     : "Add devices in Device priorities to show them here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 4)
            } else if endpoints.count > 6 {
                ScrollView {
                    deviceRows
                        .padding(.trailing, 8)
                }
                .frame(height: 178)
                .scrollIndicators(.visible)
            } else {
                deviceRows
            }
        }
    }

    private var deviceRows: some View {
        VStack(spacing: 2) {
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
