import SwiftUI

struct VolumeSlider: View {
    let title: String
    @Binding var volume: Double
    @Binding var isMuted: Bool
    var isVolumeEnabled: Bool
    var isMuteEnabled: Bool

    var body: some View {
        HStack(spacing: 8) {
            Button {
                isMuted.toggle()
            } label: {
                Image(systemName: isMuted ? "speaker.slash" : "speaker.wave.2")
            }
            .buttonStyle(.borderless)
            .disabled(!isMuteEnabled)
            .help(isMuted ? "Unmute \(title)" : "Mute \(title)")

            Slider(value: $volume, in: 0...1)
                .disabled(!isVolumeEnabled)
                .help(title)
        }
    }
}
