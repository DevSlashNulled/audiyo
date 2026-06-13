import Foundation

extension Endpoint {
    init(
        uid: String,
        direction: AudioDirection,
        transport: TransportKind,
        name: String,
        channels: Int,
        sampleRate: Double,
        isRunningSomewhere: Bool,
        deviceID: UInt32
    ) {
        self.init(
            uid: uid,
            direction: direction,
            transport: transport,
            name: name,
            channels: channels,
            sampleRate: sampleRate,
            deviceID: deviceID,
            isRunningSomewhere: isRunningSomewhere
        )
    }
}
