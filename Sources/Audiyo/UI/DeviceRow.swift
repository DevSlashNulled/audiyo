import SwiftUI

struct DeviceRow: View {
    @State private var isHovered = false

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
                    .font(.system(size: 13))
                    .accessibilityHidden(true)

                Text(endpoint.name)
                    .font(.body)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if showsIdentifier {
                    Text("…\(endpoint.uid.suffix(8))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }

                if isSystemDefault {
                    Image(systemName: "bell")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .help("System sounds")
                        .accessibilityHidden(true)
                }

                Image(systemName: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 14)
                    .opacity(isDefault ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(
                isDefault ? Color.accentColor.opacity(0.10) : isHovered ? Color.primary.opacity(0.06) : .clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("\(endpoint.name)\n\(detailText)\n\(endpoint.channels) channels · \(Int(endpoint.sampleRate)) Hz\n\(endpoint.uid)")
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
