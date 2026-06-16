import SwiftUI

struct MenuView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            DeviceSection(
                title: "Output",
                endpoints: appState.endpoints.filter { $0.direction == .output },
                defaultUID: appState.defaultOutputUID,
                systemDefaultUID: appState.defaultSystemOutputUID,
                onSelect: { endpoint in
                    appState.userSelect(endpoint)
                    dismiss()
                }
            )

            VolumeSlider(
                title: "Output volume",
                volume: Binding(get: { appState.outputVolume }, set: { appState.setOutputVolume($0) }),
                isMuted: Binding(get: { appState.outputMuted }, set: { appState.setOutputMuted($0) }),
                isVolumeEnabled: appState.outputVolumeEnabled,
                isMuteEnabled: appState.outputMuteEnabled,
                onVolumeEditingChanged: { appState.setOutputVolumeEditing($0) }
            )

            Divider()

            DeviceSection(
                title: "Input",
                endpoints: appState.endpoints.filter { $0.direction == .input },
                defaultUID: appState.defaultInputUID,
                systemDefaultUID: nil,
                onSelect: { endpoint in
                    appState.userSelect(endpoint)
                    dismiss()
                }
            )

            Divider()

            footerControls

            Divider()

            HStack {
                Button("Refresh") {
                    appState.refresh()
                }
                Spacer()
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                    dismiss()
                } label: {
                    Image(systemName: "gearshape")
                        .accessibilityLabel("Settings")
                }
                .help("Open Settings")
                Button("Quit") {
                    NSApp.terminate(nil)
                }
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Audiyo")
                    .font(.headline)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: appState.hasHFPWarning ? "waveform.badge.exclamationmark" : "speaker.wave.2")
                .foregroundStyle(appState.hasHFPWarning ? .orange : .secondary)
        }
    }

    private var statusText: String {
        if let error = appState.lastError {
            return error
        }
        guard let lastRefresh = appState.lastRefresh else {
            return "Loading audio devices"
        }
        return "Updated \(lastRefresh.formatted(date: .omitted, time: .standard))"
    }

    private var footerControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Auto", isOn: Binding(
                get: { appState.masterAuto },
                set: { appState.setAutoEnabled($0) }
            ))

            Picker("Alerts", selection: Binding(
                get: { appState.config.alertOutputUID ?? "" },
                set: { appState.setAlertOutput(uid: $0.isEmpty ? nil : $0) }
            )) {
                Text("Follow output").tag("")
                ForEach(appState.endpoints.filter { $0.direction == .output }) { endpoint in
                    Text(endpoint.name).tag(endpoint.uid)
                }
            }

            DisclosureGroup("Recent switches") {
                if appState.recentSwitches.isEmpty {
                    Text("No switches yet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appState.recentSwitches) { entry in
                        Text("\(entry.selector.label): \(entry.name)")
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }
        }
        .font(.subheadline)
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
            Text(title)
                .font(.subheadline.weight(.semibold))

            if endpoints.isEmpty {
                Text("No \(title.lowercased()) devices")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(endpoints) { endpoint in
                    DeviceRow(
                        endpoint: endpoint,
                        isDefault: endpoint.uid == defaultUID,
                        isSystemDefault: endpoint.uid == systemDefaultUID,
                        action: { onSelect(endpoint) }
                    )
                }
            }
        }
    }
}
