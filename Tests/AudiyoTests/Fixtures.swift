import Foundation
@testable import Audiyo

enum Fixtures {
    static let baseDate = Date(timeIntervalSinceReferenceDate: 800_000_000)

    static let soloCast = Endpoint(
        uid: "solocast-input",
        direction: .input,
        transport: .usb,
        name: "HyperX SoloCast 2",
        channels: 1,
        sampleRate: 48_000,
        deviceID: 10
    )

    static let accentumInput = Endpoint(
        uid: "accentum-input",
        direction: .input,
        transport: .bluetooth,
        name: "ACCENTUM Plus",
        channels: 1,
        sampleRate: 16_000,
        deviceID: 20
    )

    static let accentumRunningInput = Endpoint(
        uid: "accentum-input",
        direction: .input,
        transport: .bluetooth,
        name: "ACCENTUM Plus",
        channels: 1,
        sampleRate: 16_000,
        deviceID: 20,
        isRunningSomewhere: true
    )

    static let accentumOutput = Endpoint(
        uid: "accentum-output",
        direction: .output,
        transport: .bluetooth,
        name: "ACCENTUM Plus",
        channels: 2,
        sampleRate: 44_100,
        deviceID: 21
    )

    static let accentumCallModeOutput = Endpoint(
        uid: "accentum-output",
        direction: .output,
        transport: .bluetooth,
        name: "ACCENTUM Plus",
        channels: 2,
        sampleRate: 16_000,
        deviceID: 21
    )

    static let builtInMic = Endpoint(
        uid: "built-in-mic",
        direction: .input,
        transport: .builtIn,
        name: "MacBook Pro Microphone",
        channels: 1,
        sampleRate: 48_000,
        deviceID: 30
    )

    static let builtInSpeaker = Endpoint(
        uid: "built-in-speaker",
        direction: .output,
        transport: .builtIn,
        name: "MacBook Pro Speakers",
        channels: 2,
        sampleRate: 48_000,
        deviceID: 31
    )

    static let config = PriorityConfig(
        input: [
            PriorityDevice(uid: soloCast.uid, name: soloCast.name, transport: soloCast.transport),
            PriorityDevice(uid: builtInMic.uid, name: builtInMic.name, transport: builtInMic.transport),
            PriorityDevice(uid: accentumInput.uid, name: accentumInput.name, transport: accentumInput.transport, mode: .never)
        ],
        output: [
            PriorityDevice(uid: accentumOutput.uid, name: accentumOutput.name, transport: accentumOutput.transport),
            PriorityDevice(uid: builtInSpeaker.uid, name: builtInSpeaker.name, transport: builtInSpeaker.transport)
        ],
        pinnedSystemOutputUID: builtInSpeaker.uid
    )

    static func snapshot(
        endpoints: [Endpoint] = [soloCast, accentumInput, accentumOutput, builtInSpeaker],
        defaultInputUID: String? = soloCast.uid,
        defaultOutputUID: String? = accentumOutput.uid,
        defaultSystemOutputUID: String? = builtInSpeaker.uid,
        at date: Date = baseDate
    ) -> HALSnapshot {
        HALSnapshot(
            endpoints: endpoints,
            defaultInputUID: defaultInputUID,
            defaultOutputUID: defaultOutputUID,
            defaultSystemOutputUID: defaultSystemOutputUID,
            createdAt: date,
            error: nil
        )
    }
}
