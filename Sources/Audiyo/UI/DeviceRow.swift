import SwiftUI

struct DeviceRow: View {
    let endpoint: Endpoint
    let isDefault: Bool
    let isSystemDefault: Bool
    var mode: DeviceMode = .automatic
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 8) {
                TransportIcon(endpoint: endpoint, highlighted: isDefault)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(endpoint.name)
                            .lineLimit(1)
                        if isDefault {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                        if isSystemDefault {
                            Text("alerts")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if mode == .never {
                            Text("never")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }

                    Text(detailText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .contentShape(Rectangle())
    }

    private var detailText: String {
        let rate = endpoint.sampleRate > 0 ? "\(Int(endpoint.sampleRate)) Hz" : "unknown rate"
        return "\(endpoint.transport.rawValue) · \(endpoint.channels) ch · \(rate)"
    }

}
