import SwiftUI

struct TransportIcon: View {
    let endpoint: Endpoint
    var highlighted = false

    var body: some View {
        Image(systemName: iconName)
            .frame(width: 18)
            .foregroundStyle(highlighted ? Color.accentColor : Color.secondary)
            .help(endpoint.transport.rawValue)
    }

    private var iconName: String {
        switch endpoint.transport {
        case .bluetooth:
            return "headphones"
        case .builtIn:
            return endpoint.direction == .input ? "mic" : "macbook"
        case .displayPort, .hdmi:
            return "display"
        case .usb:
            return "cable.connector"
        case .airPlay:
            return "airplayaudio"
        case .unknown:
            return endpoint.direction == .input ? "mic.circle" : "speaker"
        }
    }
}
