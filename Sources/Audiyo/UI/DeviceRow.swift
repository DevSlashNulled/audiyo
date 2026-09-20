import SwiftUI

struct DeviceRow: View {
    let endpoint: Endpoint
    let isDefault: Bool
    let isSystemDefault: Bool
    var showsIdentifier = false
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 8) {
                TransportIcon(endpoint: endpoint, highlighted: isDefault)

                VStack(alignment: .leading, spacing: 2) {
                    Text(endpoint.name)
                        .lineLimit(1)

                    Text(detailText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if isDefault {
                    Label("In use", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                        .fixedSize()
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(isDefault ? Color.accentColor.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("\(endpoint.name)\n\(endpoint.channels) channels · \(Int(endpoint.sampleRate)) Hz\n\(endpoint.uid)")
        .accessibilityLabel(endpoint.name)
        .accessibilityValue("\(isDefault ? "In use" : "Available"). \(detailText)")
        .accessibilityHint("Use this device for now. Choose Use my list again to return to your saved order.")
    }

    private var detailText: String {
        var detail = endpoint.transport.rawValue
        if showsIdentifier {
            detail += " · \(endpoint.uid.suffix(8))"
        }
        if isSystemDefault {
            detail += " · System sounds"
        }
        return detail
    }
}
