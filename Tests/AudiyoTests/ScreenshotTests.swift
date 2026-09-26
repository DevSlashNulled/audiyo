import AppKit
import SwiftUI
import XCTest
@testable import Audiyo

@MainActor
final class ScreenshotTests: XCTestCase {
    func testCaptureReadmeScreenshots() async throws {
        guard let path = ProcessInfo.processInfo.environment["AUDIYO_CAPTURE_DIR"] else {
            throw XCTSkip("Set AUDIYO_CAPTURE_DIR to capture the README screenshots.")
        }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let appState = try makeAppState()

        let menu = MenuView()
            .environment(appState)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        try await capture(menu, name: "menu", directory: directory)

        let priorities = DevicesTab()
            .padding(20)
            .environment(appState)
            .frame(width: 760, height: 460)
            .background(Color(nsColor: .windowBackgroundColor))
        try await capture(priorities, name: "priorities", directory: directory, titled: "Device priorities")
    }

    func testCaptureMenuStates() async throws {
        guard let path = ProcessInfo.processInfo.environment["AUDIYO_CAPTURE_DIR"] else {
            throw XCTSkip("Set AUDIYO_CAPTURE_DIR to capture menu states.")
        }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let appState = try makeAppState()
        let menu = MenuView()
            .environment(appState)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))

        let savedConfig = appState.config
        appState.config = PriorityConfig()
        try await capture(menu, name: "menu-empty", directory: directory)

        appState.config = savedConfig
        appState.endpoints = []
        try await capture(menu, name: "menu-offline", directory: directory)

        appState.config = PriorityConfig()
        for direction in AudioDirection.allCases {
            for index in 1...8 {
                let endpoint = Endpoint(
                    uid: "\(direction.rawValue)-interface-\(index)",
                    direction: direction,
                    transport: .usb,
                    name: "Focusrite Scarlett 18i20 USB Audio Interface",
                    channels: 2,
                    sampleRate: 48_000,
                    deviceID: UInt32(index)
                )
                appState.endpoints.append(endpoint)
                appState.config.upsert(
                    PriorityDevice(uid: endpoint.uid, name: endpoint.name, transport: endpoint.transport),
                    direction: direction
                )
            }
        }
        appState.defaultOutputUID = "output-interface-2"
        appState.defaultInputUID = "input-interface-2"
        try await capture(menu, name: "menu-many", directory: directory)
    }

    private func makeAppState() throws -> AppState {
        let configURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("config.json")
        let appState = AppState(configStore: ConfigStore(url: configURL), startHAL: false)
        let now = Date()

        let endpoints = [
            Endpoint(uid: "desk-speakers", direction: .output, transport: .usb, name: "Desk Speakers", channels: 2, sampleRate: 48_000, deviceID: 1),
            Endpoint(uid: "airpods-output", direction: .output, transport: .bluetooth, name: "AirPods Pro", channels: 2, sampleRate: 48_000, deviceID: 2),
            Endpoint(uid: "builtin-speakers", direction: .output, transport: .builtIn, name: "MacBook Pro Speakers", channels: 2, sampleRate: 48_000, deviceID: 3),
            Endpoint(uid: "usb-mic", direction: .input, transport: .usb, name: "USB Microphone", channels: 1, sampleRate: 48_000, deviceID: 4),
            Endpoint(uid: "airpods-input", direction: .input, transport: .bluetooth, name: "AirPods Pro", channels: 1, sampleRate: 24_000, deviceID: 5),
            Endpoint(uid: "builtin-mic", direction: .input, transport: .builtIn, name: "MacBook Pro Microphone", channels: 1, sampleRate: 48_000, deviceID: 6),
        ]

        func device(_ uid: String, _ name: String, _ transport: TransportKind, _ mode: PriorityMode) -> PriorityDevice {
            PriorityDevice(uid: uid, name: name, transport: transport, mode: mode, lastSeen: now, isUserConfigured: mode == .automatic)
        }

        var config = PriorityConfig(
            input: [
                device("usb-mic", "USB Microphone", .usb, .automatic),
                device("builtin-mic", "MacBook Pro Microphone", .builtIn, .automatic),
                device("airpods-input", "AirPods Pro", .bluetooth, .never),
            ],
            output: [
                device("desk-speakers", "Desk Speakers", .usb, .automatic),
                device("airpods-output", "AirPods Pro", .bluetooth, .automatic),
                device("builtin-speakers", "MacBook Pro Speakers", .builtIn, .automatic),
                device("living-room", "Living Room", .airPlay, .never),
                device("display-audio", "LG UltraFine Display", .displayPort, .never),
            ],
            pinnedSystemOutputUID: "builtin-speakers"
        )
        config.notificationsEnabled = true

        appState.config = config
        appState.endpoints = endpoints.sorted()
        appState.defaultOutputUID = "desk-speakers"
        appState.defaultInputUID = "usb-mic"
        appState.defaultSystemOutputUID = "builtin-speakers"
        appState.lastRefresh = now
        appState.outputVolume = 0.62
        appState.outputVolumeEnabled = true
        appState.outputMuteEnabled = true
        return appState
    }

    private func capture<Content: View>(_ content: Content, name: String, directory: URL, titled title: String? = nil) async throws {
        for (suffix, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            let hosting = NSHostingView(rootView: content)
            hosting.frame = CGRect(origin: .zero, size: hosting.fittingSize)
            let window = CapturePanel(
                contentRect: hosting.frame,
                styleMask: title == nil ? [.borderless, .nonactivatingPanel] : [.titled, .closable, .miniaturizable, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: appearance)
            window.contentView = hosting
            if let title {
                window.title = title
            } else {
                window.isOpaque = false
                window.backgroundColor = .clear
            }
            window.makeKeyAndOrderFront(nil)
            defer { window.close() }
            try await Task.sleep(for: .milliseconds(400))

            let view = try XCTUnwrap(title == nil ? window.contentView : window.contentView?.superview)
            view.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            let scale = 2
            let bitmap = try XCTUnwrap(NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(view.bounds.width) * scale,
                pixelsHigh: Int(view.bounds.height) * scale,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            ))
            bitmap.size = view.bounds.size
            view.cacheDisplay(in: view.bounds, to: bitmap)
            let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
            try data.write(to: directory.appendingPathComponent("\(name)-\(suffix).png"))
        }
    }
}

private final class CapturePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
