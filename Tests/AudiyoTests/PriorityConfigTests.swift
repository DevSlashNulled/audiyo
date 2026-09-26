import XCTest
@testable import Audiyo

final class PriorityConfigTests: XCTestCase {
    func testConnectedPrioritiesFollowSavedOrderAndExcludeOtherDevices() {
        let first = Fixtures.builtInSpeaker
        let second = Fixtures.accentumOutput
        let alerts = Endpoint(uid: "alerts", direction: .output, transport: .usb, name: "Alerts", channels: 2, sampleRate: 48_000, deviceID: 100)
        let unknown = Endpoint(uid: "unknown", direction: .output, transport: .hdmi, name: "Display", channels: 2, sampleRate: 48_000, deviceID: 101)
        let config = PriorityConfig(output: [
            PriorityDevice(uid: first.uid, name: first.name, transport: first.transport, isUserConfigured: true),
            PriorityDevice(uid: alerts.uid, name: alerts.name, transport: alerts.transport, mode: .never, isUserConfigured: true),
            PriorityDevice(uid: second.uid, name: second.name, transport: second.transport)
        ], pinnedSystemOutputUID: alerts.uid)

        XCTAssertEqual(config.connectedPriorityEndpoints(for: .output, in: [second, alerts, unknown, first]), [first, second])
        XCTAssertTrue(PriorityConfig().connectedPriorityEndpoints(for: .output, in: [first, second]).isEmpty)
    }

    func testDisconnectedPrioritiesReturnToTheirSavedPositionWhenReconnected() {
        let config = Fixtures.config

        XCTAssertEqual(config.connectedPriorityEndpoints(for: .output, in: [Fixtures.builtInSpeaker]), [Fixtures.builtInSpeaker])
        XCTAssertTrue(config.connectedPriorityEndpoints(for: .output, in: []).isEmpty)
        XCTAssertEqual(
            config.connectedPriorityEndpoints(for: .output, in: [Fixtures.builtInSpeaker, Fixtures.accentumOutput]),
            [Fixtures.accentumOutput, Fixtures.builtInSpeaker]
        )
    }

    func testConnectedPrioritiesMatchDirectionWhenDeviceUIDIsShared() {
        let output = Fixtures.builtInSpeaker
        let input = Endpoint(uid: output.uid, direction: .input, transport: .builtIn, name: "Microphone", channels: 1, sampleRate: 48_000, deviceID: output.deviceID)
        let config = PriorityConfig(
            input: [PriorityDevice(uid: input.uid, name: input.name, transport: input.transport)],
            output: [PriorityDevice(uid: output.uid, name: output.name, transport: output.transport)]
        )

        XCTAssertEqual(config.connectedPriorityEndpoints(for: .input, in: [output, input]), [input])
        XCTAssertEqual(config.connectedPriorityEndpoints(for: .output, in: [input, output]), [output])
        XCTAssertTrue(config.connectedPriorityEndpoints(for: .output, in: [input]).isEmpty)
        XCTAssertTrue(config.connectedPriorityEndpoints(for: .input, in: [output]).isEmpty)
    }

    func testConnectedPrioritiesReflectAddReorderAndRemoveChanges() {
        let first = Fixtures.builtInSpeaker
        let second = Fixtures.accentumOutput
        let endpoints = [second, first]
        var config = PriorityConfig(output: [
            PriorityDevice(uid: first.uid, name: first.name, transport: first.transport),
            PriorityDevice(uid: second.uid, name: second.name, transport: second.transport, mode: .never)
        ])

        XCTAssertEqual(config.connectedPriorityEndpoints(for: .output, in: endpoints), [first])

        config.addToPriority(uid: second.uid, direction: .output)
        XCTAssertEqual(config.connectedPriorityEndpoints(for: .output, in: endpoints), [first, second])

        config.setPriority([second.uid, first.uid], for: .output)
        XCTAssertEqual(config.connectedPriorityEndpoints(for: .output, in: endpoints), [second, first])

        config.removeFromPriority(uid: first.uid, direction: .output)
        XCTAssertEqual(config.connectedPriorityEndpoints(for: .output, in: endpoints), [second])

        config.removeFromPriority(uid: second.uid, direction: .output)
        XCTAssertTrue(config.connectedPriorityEndpoints(for: .output, in: endpoints).isEmpty)
    }

    func testReorderingFilteredPrioritiesPreservesOtherDevicesAndTheirSettings() {
        let first = PriorityDevice(uid: "first", name: "First", transport: .usb, mode: .automatic, lastSeen: Fixtures.baseDate, isUserConfigured: true)
        let other = PriorityDevice(uid: "other", name: "Other", transport: .airPlay, mode: .never, lastSeen: Fixtures.baseDate)
        let second = PriorityDevice(uid: "second", name: "Second", transport: .builtIn, mode: .automatic)
        let excluded = PriorityDevice(uid: "excluded", name: "Excluded", transport: .bluetooth, mode: .never, isUserConfigured: true)
        let microphone = PriorityDevice(uid: "other", name: "Microphone", transport: .usb, mode: .automatic)
        var config = PriorityConfig(input: [microphone], output: [first, other, second, excluded], pinnedSystemOutputUID: other.uid)

        XCTAssertEqual(config.preferredDevices(for: .output), [first, second])
        XCTAssertEqual(config.priority(for: .output), [first.uid, second.uid])

        config.setPriority([second.uid, first.uid], for: .output)

        XCTAssertEqual(config.preferredDevices(for: .output), [second, first])
        XCTAssertEqual(config.output, [second, first, other, excluded])
        XCTAssertEqual(config.input, [microphone])
        XCTAssertEqual(config.pinnedSystemOutputUID, other.uid)
    }

    func testAddingAndRemovingPrioritiesPreservesRecordsAndAlertPinAcrossPersistence() throws {
        let first = PriorityDevice(uid: "first", name: "First", transport: .usb, mode: .automatic)
        let second = PriorityDevice(uid: "second", name: "Second", transport: .builtIn, mode: .automatic)
        let other = PriorityDevice(uid: "other", name: "Other", transport: .airPlay, mode: .never, lastSeen: Fixtures.baseDate)
        let microphone = PriorityDevice(uid: other.uid, name: "Microphone", transport: .usb, mode: .never)
        var config = PriorityConfig(input: [microphone], output: [first, other, second], pinnedSystemOutputUID: other.uid)

        config.addToPriority(uid: other.uid, direction: .output)

        var added = other
        added.mode = .automatic
        added.isUserConfigured = true
        XCTAssertEqual(config.preferredDevices(for: .output), [first, second, added])
        XCTAssertEqual(config.knownDevice(uid: other.uid, direction: .output), added)
        XCTAssertEqual(config.input, [microphone])

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ConfigStore(url: directory.appendingPathComponent("config.json"))
        try store.save(config)
        var loaded = try store.load()
        XCTAssertEqual(loaded, config)

        loaded.removeFromPriority(uid: other.uid, direction: .output)

        var removed = added
        removed.mode = .never
        XCTAssertEqual(loaded.preferredDevices(for: .output), [first, second])
        XCTAssertEqual(loaded.knownDevice(uid: other.uid, direction: .output), removed)
        XCTAssertEqual(loaded.output.count, 3)
        XCTAssertEqual(loaded.input, [microphone])
        XCTAssertEqual(loaded.pinnedSystemOutputUID, other.uid)

        try store.save(loaded)
        XCTAssertEqual(try store.load(), loaded)
    }

    func testDecodingKeepsModesOrderingAndAlertDevice() throws {
        let data = Data("""
        {
            "version": 1,
            "masterAutoEnabled": false,
            "pinnedSystemOutputUID": "other",
            "input": [
                {"uid":"headset","name":"Headset","transport":"Bluetooth","mode":"automatic","isUserConfigured":true},
                {"uid":"excluded-mic","name":"Microphone","transport":"USB","mode":"never","isUserConfigured":true}
            ],
            "output": [
                {"uid":"first","name":"First","transport":"USB","mode":"automatic","isUserConfigured":true},
                {"uid":"other","name":"Other","transport":"AirPlay","mode":"never","isUserConfigured":true},
                {"uid":"discovered","name":"Discovered","transport":"AirPlay","mode":"automatic","isUserConfigured":false}
            ]
        }
        """.utf8)

        let config = try JSONDecoder().decode(PriorityConfig.self, from: data)

        XCTAssertEqual(config.priority(for: .input), ["headset"])
        XCTAssertEqual(config.priority(for: .output), ["first", "discovered"])
        XCTAssertEqual(config.output.map(\.uid), ["first", "other", "discovered"])
        XCTAssertEqual(config.input.map(\.mode), [.automatic, .never])
        XCTAssertEqual(config.output.map(\.mode), [.automatic, .never, .automatic])
        XCTAssertEqual(config.output.map(\.isUserConfigured), [true, true, false])
        XCTAssertEqual(config.pinnedSystemOutputUID, "other")
        XCTAssertFalse(config.masterAutoEnabled)
        XCTAssertEqual(try JSONDecoder().decode(PriorityConfig.self, from: JSONEncoder().encode(config)), config)
    }

    func testRemovingUnconfiguredPreferenceRemembersExclusionAndKeepsAlertPin() {
        let device = PriorityDevice(uid: "speaker", name: "Speaker", transport: .airPlay, mode: .automatic, lastSeen: Fixtures.baseDate)
        var config = PriorityConfig(output: [device], pinnedSystemOutputUID: device.uid)

        config.removeFromPriority(uid: device.uid, direction: .output)

        var excluded = device
        excluded.mode = .never
        excluded.isUserConfigured = true
        XCTAssertTrue(config.priority(for: .output).isEmpty)
        XCTAssertEqual(config.output, [excluded])
        XCTAssertEqual(config.pinnedSystemOutputUID, device.uid)
    }
}
