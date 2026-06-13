import SwiftUI

@main
struct AudiyoApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environment(appState)
                .frame(width: 340)
        } label: {
            Label("Audiyo", systemImage: appState.hasHFPWarning ? "waveform.badge.exclamationmark" : "speaker.wave.2")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environment(appState)
        }
    }
}
