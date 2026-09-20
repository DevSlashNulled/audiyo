import XCTest
@testable import Audiyo

final class ConfigStoreTests: XCTestCase {
    func testLoadReturnsEmptyConfigWhenFileDoesNotExist() throws {
        let store = ConfigStore(url: temporaryURL())

        XCTAssertEqual(try store.load(), PriorityConfig())
    }

    func testSaveAndLoadRoundTripsConfig() throws {
        let store = ConfigStore(url: temporaryURL())
        let config = PriorityConfig(
            input: [PriorityDevice(uid: "mic", name: "Mic", transport: .usb, mode: .automatic, lastSeen: Date(timeIntervalSince1970: 10))],
            output: [PriorityDevice(uid: "speaker", name: "Speaker", transport: .builtIn)],
            pinnedSystemOutputUID: "speaker"
        )

        try store.save(config)

        XCTAssertEqual(try store.load(), config)
    }

    func testDisplayFlagsDefaultToMenuBarUtilityMode() throws {
        let data = Data(#"{"version":1,"input":[],"output":[]}"#.utf8)
        let config = try JSONDecoder().decode(PriorityConfig.self, from: data)

        XCTAssertTrue(config.menuBarIconVisible)
        XCTAssertFalse(config.dockIconVisible)
    }

    func testLegacyAirPlayCleanupKeepsConnectedDevicesAndRecordedPreferences() throws {
        let data = Data("""
        {
            "version": 1,
            "input": [{"uid":"mic","name":"Mic","transport":"USB","mode":"automatic","lastSeen":0}],
            "output": [
                {"uid":"stale","name":"Old Speaker","transport":"AirPlay","mode":"automatic","lastSeen":0},
                {"uid":"stale-never","name":"Old TV","transport":"AirPlay","mode":"never","lastSeen":0},
                {"uid":"connected","name":"Speaker","transport":"AirPlay","mode":"automatic","lastSeen":0},
                {"uid":"configured","name":"Configured Speaker","transport":"AirPlay","mode":"never","lastSeen":0,"isUserConfigured":true},
                {"uid":"usb","name":"USB Speaker","transport":"USB","mode":"never","lastSeen":0}
            ]
        }
        """.utf8)
        let config = try JSONDecoder().decode(PriorityConfig.self, from: data)
        XCTAssertEqual(config.output.map(\.isUserConfigured), [false, false, false, true, true])

        let endpoint = Endpoint(uid: "connected", direction: .output, transport: .airPlay, name: "Speaker", channels: 2, sampleRate: 48_000, deviceID: 100)
        let decision = Reconciler().reconcile(
            snapshot: Fixtures.snapshot(endpoints: [endpoint]),
            config: config,
            masterAuto: false
        )

        XCTAssertEqual(decision.configAmendments.input, config.input)
        XCTAssertEqual(decision.configAmendments.output.map(\.uid), ["connected", "configured", "usb"])
        XCTAssertEqual(decision.configAmendments.output.map(\.mode), [.automatic, .never, .never])
        XCTAssertEqual(decision.configAmendments.output.first?.lastSeen, Fixtures.baseDate)

        let store = ConfigStore(url: temporaryURL())
        defer { try? FileManager.default.removeItem(at: store.url.deletingLastPathComponent()) }
        try store.save(decision.configAmendments)

        XCTAssertEqual(try store.load(), decision.configAmendments)
    }

    func testForgettingDeviceClearsOnlyItsOutputAlertPin() {
        var config = PriorityConfig(pinnedSystemOutputUID: "alerts")

        config.remove(uid: "alerts", direction: .input)
        XCTAssertEqual(config.pinnedSystemOutputUID, "alerts")
        config.remove(uid: "other", direction: .output)
        XCTAssertEqual(config.pinnedSystemOutputUID, "alerts")
        config.remove(uid: "alerts", direction: .output)
        XCTAssertNil(config.pinnedSystemOutputUID)
    }

    func testDisplayFlagsKeepAtLeastOneControlSurfaceVisible() {
        var config = PriorityConfig()

        config.setMenuBarIconVisible(false)

        XCTAssertFalse(config.menuBarIconVisible)
        XCTAssertTrue(config.dockIconVisible)

        config.setDockIconVisible(false)

        XCTAssertTrue(config.menuBarIconVisible)
        XCTAssertFalse(config.dockIconVisible)
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("config.json")
    }
}
