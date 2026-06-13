import Foundation

struct DiagnosticsReport {
    var generatedAt: Date
    var bundleURL: URL
    var appVersion: String
    var buildNumber: String
    var config: PriorityConfig
    var endpoints: [Endpoint]
    var defaultInputUID: String?
    var defaultOutputUID: String?
    var defaultSystemOutputUID: String?
    var recentSwitches: [SwitchRecord]
    var lastError: String?

    func render() -> String {
        var lines: [String] = []
        lines.append("Audiyo Diagnostics")
        lines.append("Generated: \(generatedAt.formatted(date: .numeric, time: .standard))")
        lines.append("Version: \(appVersion) (\(buildNumber))")
        lines.append("Bundle: \(bundleURL.path)")
        lines.append("")
        lines.append("Status")
        lines.append("- Auto: \(config.masterAutoEnabled ? "enabled" : "disabled")")
        lines.append("- Notifications: \(config.notificationsEnabled ? "enabled" : "disabled")")
        lines.append("- Bluetooth inputs default to Never: \(config.newBluetoothInputsNever ? "yes" : "no")")
        lines.append("- Alert output UID: \(config.alertOutputUID ?? "follow output")")
        lines.append("- Last error: \(lastError ?? "none")")
        lines.append("")
        lines.append("Defaults")
        lines.append("- Input: \(defaultInputUID ?? "none")")
        lines.append("- Output: \(defaultOutputUID ?? "none")")
        lines.append("- Alerts: \(defaultSystemOutputUID ?? "none")")
        lines.append("")
        lines.append("Priority")
        lines.append(contentsOf: renderDevices("Input", config.input))
        lines.append(contentsOf: renderDevices("Output", config.output))
        lines.append("")
        lines.append("Endpoints")
        if endpoints.isEmpty {
            lines.append("- none")
        } else {
            for endpoint in endpoints.sorted() {
                lines.append("- \(endpoint.direction.rawValue): \(endpoint.name) [\(endpoint.transport.rawValue), \(endpoint.channels) ch, \(Int(endpoint.sampleRate)) Hz] uid=\(endpoint.uid)")
            }
        }
        lines.append("")
        lines.append("Recent Switches")
        if recentSwitches.isEmpty {
            lines.append("- none")
        } else {
            for entry in recentSwitches {
                lines.append("- \(entry.date.formatted(date: .numeric, time: .standard)) \(entry.selector.label) -> \(entry.name) reason=\(entry.reason)")
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private func renderDevices(_ title: String, _ devices: [PriorityDevice]) -> [String] {
        guard !devices.isEmpty else { return ["- \(title): none"] }
        return devices.map { device in
            "- \(title): \(device.name) [\(device.transport.rawValue), \(device.mode.rawValue)] uid=\(device.uid)"
        }
    }
}
