import AudioToolbox
import CoreAudio
import Foundation
import os

private let audioControlElements: [AudioObjectPropertyElement] = [kAudioObjectPropertyElementMain, 1]

final class AudioHAL {
    private let queue = DispatchQueue(label: "ca.5350.audiyo.hal")
    private var isStarted = false
    private var observedDeviceIDs: Set<AudioDeviceID> = []
    private var pendingDefaultSets = HALDefaultSetLedger()
    private var refreshTimer: DispatchSourceTimer?

    var onSnapshot: (@Sendable (HALSnapshot) -> Void)?
    var onVolumeChange: (@Sendable () -> Void)?

    deinit {
        refreshTimer?.cancel()
    }

    func start() {
        queue.async {
            guard !self.isStarted else { return }
            self.isStarted = true
            self.registerSystemListeners()
            self.emitSnapshot()
            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now() + 60 * 60, repeating: 60 * 60, leeway: .seconds(60))
            timer.setEventHandler { [weak self] in
                self?.emitSnapshot()
            }
            self.refreshTimer = timer
            timer.resume()
        }
    }

    func refresh() {
        queue.async {
            self.emitSnapshot()
        }
    }

    func setDefault(uid: String, selector: DefaultSelector, completion: (@Sendable (Result<Void, Error>) -> Void)? = nil) {
        queue.async {
            do {
                let snapshot = try self.readSnapshot()
                guard let direction = selector.direction else {
                    throw AudioHALError(status: kAudioHardwareIllegalOperationError)
                }
                guard let endpoint = snapshot.endpoints.first(where: { $0.uid == uid && $0.direction == direction }) else {
                    throw AudioHALError(status: kAudioHardwareBadDeviceError)
                }
                try self.waitUntilAlive(deviceID: endpoint.deviceID)
                _ = self.pendingDefaultSets.record(selector: selector.halSelector, deviceID: endpoint.deviceID)
                try AudioObjectID.system.writeAudioDeviceID(endpoint.deviceID, selector: selector.coreAudioSelector)
                completion?(.success(()))
                self.emitSnapshot()
            } catch {
                completion?(.failure(error))
            }
        }
    }

    func volumeState(deviceID: AudioDeviceID, direction: AudioDirection, completion: @escaping @Sendable (Result<HALVolumeState, Error>) -> Void) {
        queue.async {
            completion(Result {
                try self.readVolumeState(deviceID: deviceID, direction: direction)
            })
        }
    }

    func setVolume(_ volume: Float, deviceID: AudioDeviceID, direction: AudioDirection, completion: (@Sendable (Result<Void, Error>) -> Void)? = nil) {
        queue.async {
            completion?(Result {
                try self.writeVolume(min(max(volume, 0), 1), deviceID: deviceID, direction: direction)
            })
        }
    }

    func setMuted(_ muted: Bool, deviceID: AudioDeviceID, direction: AudioDirection, completion: (@Sendable (Result<Void, Error>) -> Void)? = nil) {
        queue.async {
            completion?(Result {
                try self.writeMute(muted, deviceID: deviceID, direction: direction)
            })
        }
    }

    private func readVolumeState(deviceID: AudioDeviceID, direction: AudioDirection) throws -> HALVolumeState {
        let volumeAddress = try firstAvailableVolumeAddress(deviceID: deviceID, direction: direction)
        let muteAddress = firstAvailableMuteAddress(deviceID: deviceID, direction: direction)

        let volume = try volumeAddress.map { try deviceID.readFloat32($0) }
        let volumeSettable = try volumeAddress.map { try deviceID.isPropertySettable($0) } ?? false
        let muted = try muteAddress.map { try deviceID.readBool($0) }
        let muteSettable = try muteAddress.map { try deviceID.isPropertySettable($0) } ?? false

        return HALVolumeState(volume: volume, isVolumeSettable: volumeSettable, isMuted: muted, isMuteSettable: muteSettable)
    }

    private func writeVolume(_ volume: Float, deviceID: AudioDeviceID, direction: AudioDirection) throws {
        guard let address = try firstAvailableVolumeAddress(deviceID: deviceID, direction: direction) else {
            throw AudioHALError(status: kAudioHardwareUnknownPropertyError)
        }
        guard try deviceID.isPropertySettable(address) else {
            throw AudioHALError(status: kAudioHardwareIllegalOperationError)
        }
        try deviceID.writeFloat32(volume, address: address)
    }

    private func writeMute(_ muted: Bool, deviceID: AudioDeviceID, direction: AudioDirection) throws {
        guard let address = firstAvailableMuteAddress(deviceID: deviceID, direction: direction) else {
            throw AudioHALError(status: kAudioHardwareUnknownPropertyError)
        }
        guard try deviceID.isPropertySettable(address) else {
            throw AudioHALError(status: kAudioHardwareIllegalOperationError)
        }
        try deviceID.writeBool(muted, address: address)
    }

    private func firstAvailableVolumeAddress(deviceID: AudioDeviceID, direction: AudioDirection) throws -> AudioObjectPropertyAddress? {
        try firstAvailableAddress(
            deviceID: deviceID,
            selector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            direction: direction,
            elements: audioControlElements
        )
    }

    private func firstAvailableMuteAddress(deviceID: AudioDeviceID, direction: AudioDirection) -> AudioObjectPropertyAddress? {
        try? firstAvailableAddress(
            deviceID: deviceID,
            selector: kAudioDevicePropertyMute,
            direction: direction,
            elements: audioControlElements
        )
    }

    private func firstAvailableAddress(deviceID: AudioDeviceID, selector: AudioObjectPropertySelector, direction: AudioDirection, elements: [AudioObjectPropertyElement]) throws -> AudioObjectPropertyAddress? {
        for element in elements {
            let address = AudioObjectPropertyAddress(
                mSelector: selector,
                mScope: direction.coreAudioScope,
                mElement: element
            )
            if deviceID.hasProperty(address) {
                return address
            }
        }
        return nil
    }

    private func emitSnapshot() {
        do {
            let snapshot = try readSnapshot()
            updateDeviceListeners(for: Set(snapshot.endpoints.map(\.deviceID)))
            onSnapshot?(snapshot)
        } catch {
            onSnapshot?(HALSnapshot(endpoints: [], defaultInputUID: nil, defaultOutputUID: nil, defaultSystemOutputUID: nil, createdAt: Date(), error: String(describing: error)))
        }
    }

    private func readSnapshot() throws -> HALSnapshot {
        let deviceIDs = try AudioObjectID.system.readAudioObjectIDs(selector: kAudioHardwarePropertyDevices)
        let defaultInput = try? AudioObjectID.system.readAudioDeviceID(selector: kAudioHardwarePropertyDefaultInputDevice)
        let defaultOutput = try? AudioObjectID.system.readAudioDeviceID(selector: kAudioHardwarePropertyDefaultOutputDevice)
        let defaultSystemOutput = try? AudioObjectID.system.readAudioDeviceID(selector: kAudioHardwarePropertyDefaultSystemOutputDevice)

        let endpoints = deviceIDs.flatMap { deviceID in
            readEndpoints(deviceID: deviceID)
        }

        return HALSnapshot(
            endpoints: endpoints,
            defaultInputUID: defaultInput.flatMap { try? $0.readString(selector: kAudioDevicePropertyDeviceUID) },
            defaultOutputUID: defaultOutput.flatMap { try? $0.readString(selector: kAudioDevicePropertyDeviceUID) },
            defaultSystemOutputUID: defaultSystemOutput.flatMap { try? $0.readString(selector: kAudioDevicePropertyDeviceUID) },
            createdAt: Date(),
            error: nil
        )
    }

    private func readEndpoints(deviceID: AudioDeviceID) -> [Endpoint] {
        let name = (try? deviceID.readString(selector: kAudioObjectPropertyName)) ?? "Unknown Device"
        let uid = (try? deviceID.readString(selector: kAudioDevicePropertyDeviceUID)) ?? "device-\(deviceID)"
        let transport = (try? deviceID.readUInt32(selector: kAudioDevicePropertyTransportType)).map(TransportKind.init(coreAudioValue:)) ?? .unknown
        let sampleRate = (try? deviceID.readDouble(selector: kAudioDevicePropertyNominalSampleRate)) ?? 0
        let isRunningSomewhere = ((try? deviceID.readUInt32(selector: kAudioDevicePropertyDeviceIsRunningSomewhere)) ?? 0) != 0

        return AudioDirection.allCases.compactMap { direction in
            let channels = ((try? deviceID.channelCount(direction: direction)) ?? 0)
            guard channels > 0 else { return nil }
            return Endpoint(uid: uid, direction: direction, transport: transport, name: name, channels: channels, sampleRate: sampleRate, deviceID: deviceID, isRunningSomewhere: isRunningSomewhere)
        }
    }

    private func registerSystemListeners() {
        [
            AudioObjectPropertyAddress(selector: kAudioHardwarePropertyDevices),
            AudioObjectPropertyAddress(selector: kAudioHardwarePropertyDefaultInputDevice),
            AudioObjectPropertyAddress(selector: kAudioHardwarePropertyDefaultOutputDevice),
            AudioObjectPropertyAddress(selector: kAudioHardwarePropertyDefaultSystemOutputDevice)
        ].forEach { address in
            registerListener(objectID: .system, address: address)
        }
    }

    private func updateDeviceListeners(for deviceIDs: Set<AudioDeviceID>) {
        let newDeviceIDs = deviceIDs.subtracting(observedDeviceIDs)
        observedDeviceIDs.formUnion(newDeviceIDs)

        for deviceID in newDeviceIDs {
            [
                AudioObjectPropertyAddress(selector: kAudioDevicePropertyNominalSampleRate),
                AudioObjectPropertyAddress(selector: kAudioDevicePropertyDeviceIsAlive),
                AudioObjectPropertyAddress(selector: kAudioDevicePropertyDeviceIsRunningSomewhere)
            ].forEach { address in
                registerListener(objectID: deviceID, address: address)
            }

            volumeControlAddresses(for: deviceID).forEach { address in
                registerListener(objectID: deviceID, address: address)
            }
        }
    }

    private func volumeControlAddresses(for deviceID: AudioDeviceID) -> [AudioObjectPropertyAddress] {
        AudioDirection.allCases.flatMap { direction in
            audioControlElements.flatMap { element in
                [
                    AudioObjectPropertyAddress(mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume, mScope: direction.coreAudioScope, mElement: element),
                    AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute, mScope: direction.coreAudioScope, mElement: element)
                ]
            }
        }
        .filter { deviceID.hasProperty($0) }
    }

    private func registerListener(objectID: AudioObjectID, address: AudioObjectPropertyAddress) {
        var address = address
        let status = AudioObjectAddPropertyListenerBlock(objectID, &address, queue) { [weak self] _, _ in
            self?.handlePropertyEvent(objectID: objectID, address: address)
        }

        if status != noErr {
            Logger.hal.warning("listener registration failed objectID=\(objectID) selector=\(address.mSelector) status=\(status)")
        }
    }

    private func waitUntilAlive(deviceID: AudioDeviceID) throws {
        let deadline = Date().addingTimeInterval(1)
        while Date() < deadline {
            if ((try? deviceID.readBool(AudioObjectPropertyAddress(selector: kAudioDevicePropertyDeviceIsAlive))) ?? false) {
                return
            }
            Thread.sleep(forTimeInterval: 0.01)
        }
        throw AudioHALError(status: kAudioHardwareBadDeviceError)
    }

    private func handlePropertyEvent(objectID: AudioObjectID, address: AudioObjectPropertyAddress) {
        if isVolumeControlEvent(address) {
            onVolumeChange?()
            return
        }

        if objectID == AudioObjectID.system,
           let selector = DefaultSelector(coreAudioSelector: address.mSelector),
           let deviceID = try? AudioObjectID.system.readAudioDeviceID(selector: address.mSelector),
           pendingDefaultSets.consume(selector: selector.halSelector, deviceID: deviceID) != nil {
            Logger.hal.debug("consumed self default event selector=\(address.mSelector) deviceID=\(deviceID)")
        }
        emitSnapshot()
    }

    private func isVolumeControlEvent(_ address: AudioObjectPropertyAddress) -> Bool {
        address.mSelector == kAudioHardwareServiceDeviceProperty_VirtualMainVolume || address.mSelector == kAudioDevicePropertyMute
    }
}

private extension DefaultSelector {
    init?(coreAudioSelector: AudioObjectPropertySelector) {
        switch coreAudioSelector {
        case kAudioHardwarePropertyDefaultInputDevice:
            self = .input
        case kAudioHardwarePropertyDefaultOutputDevice:
            self = .output
        case kAudioHardwarePropertyDefaultSystemOutputDevice:
            self = .systemOutput
        default:
            return nil
        }
    }

    var coreAudioSelector: AudioObjectPropertySelector {
        switch self {
        case .input:
            return kAudioHardwarePropertyDefaultInputDevice
        case .output:
            return kAudioHardwarePropertyDefaultOutputDevice
        case .systemOutput:
            return kAudioHardwarePropertyDefaultSystemOutputDevice
        }
    }

    var halSelector: HALDefaultSelector {
        switch self {
        case .input:
            return .input
        case .output:
            return .output
        case .systemOutput:
            return .systemOutput
        }
    }
}

private extension TransportKind {
    init(coreAudioValue value: UInt32) {
        switch value {
        case kAudioDeviceTransportTypeAirPlay:
            self = .airPlay
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            self = .bluetooth
        case kAudioDeviceTransportTypeBuiltIn:
            self = .builtIn
        case kAudioDeviceTransportTypeDisplayPort:
            self = .displayPort
        case kAudioDeviceTransportTypeHDMI:
            self = .hdmi
        case kAudioDeviceTransportTypeUSB:
            self = .usb
        default:
            self = .unknown
        }
    }
}
