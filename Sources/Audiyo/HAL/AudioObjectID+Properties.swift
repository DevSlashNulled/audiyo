import CoreAudio
import Foundation

extension AudioObjectID {
    static let system = AudioObjectID(kAudioObjectSystemObject)

    func hasProperty(_ address: AudioObjectPropertyAddress) -> Bool {
        var address = address
        return AudioObjectHasProperty(self, &address)
    }

    func isPropertySettable(_ address: AudioObjectPropertyAddress) throws -> Bool {
        var address = address
        var settable = DarwinBoolean(false)
        try check(AudioObjectIsPropertySettable(self, &address, &settable))
        return settable.boolValue
    }

    func readAudioObjectIDs(selector: AudioObjectPropertySelector) throws -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(selector: selector)
        var size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(self, &address, 0, nil, &size))
        guard size > 0 else { return [] }

        let count = Int(size) / MemoryLayout<AudioObjectID>.size
        var values = Array(repeating: AudioObjectID(0), count: count)
        try values.withUnsafeMutableBufferPointer { pointer in
            guard let baseAddress = pointer.baseAddress else { return }
            try check(AudioObjectGetPropertyData(self, &address, 0, nil, &size, baseAddress))
        }
        return values
    }

    func readAudioDeviceID(selector: AudioObjectPropertySelector) throws -> AudioDeviceID {
        var value = AudioDeviceID(0)
        try read(selector: selector, value: &value)
        return value
    }

    func readUInt32(selector: AudioObjectPropertySelector) throws -> UInt32 {
        var value: UInt32 = 0
        try read(selector: selector, value: &value)
        return value
    }

    func readDouble(selector: AudioObjectPropertySelector) throws -> Double {
        var value: Double = 0
        try read(selector: selector, value: &value)
        return value
    }

    func readFloat32(_ address: AudioObjectPropertyAddress) throws -> Float32 {
        var value: Float32 = 0
        try read(address: address, value: &value)
        return value
    }

    func readBool(_ address: AudioObjectPropertyAddress) throws -> Bool {
        var value: UInt32 = 0
        try read(address: address, value: &value)
        return value != 0
    }

    func readString(selector: AudioObjectPropertySelector) throws -> String {
        var value: CFString = "" as CFString
        try read(selector: selector, value: &value)
        return value as String
    }

    func channelCount(direction: AudioDirection) throws -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: direction.coreAudioScope,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(self, &address, 0, nil, &size))
        guard size > 0 else { return 0 }

        let rawPointer = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { rawPointer.deallocate() }

        let audioBufferList = rawPointer.bindMemory(to: AudioBufferList.self, capacity: 1)
        try check(AudioObjectGetPropertyData(self, &address, 0, nil, &size, audioBufferList))

        let bufferList = UnsafeMutableAudioBufferListPointer(audioBufferList)
        return bufferList.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    func writeAudioDeviceID(_ value: AudioDeviceID, selector: AudioObjectPropertySelector) throws {
        var value = value
        try write(AudioObjectPropertyAddress(selector: selector), value: &value)
    }

    func writeFloat32(_ value: Float32, address: AudioObjectPropertyAddress) throws {
        var value = value
        try write(address, value: &value)
    }

    func writeBool(_ value: Bool, address: AudioObjectPropertyAddress) throws {
        var value: UInt32 = value ? 1 : 0
        try write(address, value: &value)
    }

    private func read<T>(selector: AudioObjectPropertySelector, value: inout T) throws {
        try read(address: AudioObjectPropertyAddress(selector: selector), value: &value)
    }

    private func read<T>(address: AudioObjectPropertyAddress, value: inout T) throws {
        var address = address
        var size = UInt32(MemoryLayout<T>.size)
        try withUnsafeMutablePointer(to: &value) { pointer in
            try check(AudioObjectGetPropertyData(self, &address, 0, nil, &size, pointer))
        }
    }

    private func write<T>(_ address: AudioObjectPropertyAddress, value: inout T) throws {
        var address = address
        let size = UInt32(MemoryLayout<T>.size)
        try withUnsafeMutablePointer(to: &value) { pointer in
            try check(AudioObjectSetPropertyData(self, &address, 0, nil, size, pointer))
        }
    }
}

extension AudioObjectPropertyAddress {
    init(selector: AudioObjectPropertySelector) {
        self.init(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }
}

struct AudioHALError: Error, CustomStringConvertible {
    let status: OSStatus

    var description: String {
        "CoreAudio error \(status)"
    }
}

func check(_ status: OSStatus) throws {
    guard status == noErr else {
        throw AudioHALError(status: status)
    }
}
