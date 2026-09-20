import SwiftUI

struct VolumeSlider: View {
    let title: String
    @Binding var volume: Double
    @Binding var isMuted: Bool
    var isVolumeEnabled: Bool
    var isMuteEnabled: Bool
    var onVolumeEditingChanged: (Bool) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Volume")
                Spacer()
                if isVolumeEnabled {
                    Text(isMuted ? "Muted" : "\(Int(volume * 100))%")
                        .monospacedDigit()
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button {
                    isMuted.toggle()
                } label: {
                    Image(systemName: isMuted ? "speaker.slash" : "speaker.wave.2")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .disabled(!isMuteEnabled)
                .help(isMuted ? "Unmute output" : "Mute output")
                .accessibilityLabel(isMuted ? "Unmute output" : "Mute output")

                Slider(value: $volume, in: 0...1, onEditingChanged: onVolumeEditingChanged)
                    .disabled(!isVolumeEnabled)
                    .help(title)
                    .accessibilityLabel(title)
                    .accessibilityValue("\(Int(volume * 100)) percent")
            }

            if !isVolumeEnabled {
                Text("Volume control is not available for this device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
