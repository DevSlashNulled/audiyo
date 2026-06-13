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

    func testSeedFlagsBluetoothInputsNever() {
        let now = Date(timeIntervalSince1970: 20)
        let endpoints = [
            Endpoint(uid: "bt-mic", direction: .input, transport: .bluetooth, name: "Headset Mic", channels: 1, sampleRate: 16_000, deviceID: 1),
            Endpoint(uid: "usb-mic", direction: .input, transport: .usb, name: "SoloCast", channels: 1, sampleRate: 48_000, deviceID: 2),
            Endpoint(uid: "bt-out", direction: .output, transport: .bluetooth, name: "Headset", channels: 2, sampleRate: 44_100, deviceID: 3)
        ]

        let config = ConfigStore(url: temporaryURL()).seed(from: endpoints, now: now)

        XCTAssertEqual(config.inputPriority, ["bt-mic", "usb-mic"])
        XCTAssertEqual(config.outputPriority, ["bt-out"])
        XCTAssertEqual(config.knownDevice(uid: "bt-mic", direction: .input)?.mode, .never)
        XCTAssertEqual(config.knownDevice(uid: "bt-out", direction: .output)?.mode, .automatic)
        XCTAssertEqual(config.knownDevice(uid: "bt-mic", direction: .input)?.lastSeen, now)
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("config.json")
    }
}
