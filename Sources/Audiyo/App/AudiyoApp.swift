import SwiftUI

@main
struct AudiyoApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra(isInserted: Binding(
            get: { appState.menuBarIconVisible },
            set: { appState.setMenuBarIconVisible($0) }
        )) {
            MenuView()
                .environment(appState)
                .frame(width: 380)
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
