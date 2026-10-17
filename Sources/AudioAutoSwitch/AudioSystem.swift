import CoreAudio
import Foundation

struct OutputDevice: Identifiable, Hashable {
  let id: AudioDeviceID
  let uid: String
  let name: String
}

/// Thin wrapper around the Core Audio calls the app needs.
enum AudioSystem {
  private static let system = AudioObjectID(kAudioObjectSystemObject)

  private static func address(
    _ selector: AudioObjectPropertySelector,
    _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
  ) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
  }

  private static func string(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
    var addr = address(selector)
    var value: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value) == noErr, let value else { return nil }
    return value.takeRetainedValue() as String
  }

  private static func hasOutput(_ id: AudioDeviceID) -> Bool {
    var addr = address(kAudioDevicePropertyStreams, kAudioObjectPropertyScopeOutput)
    var size: UInt32 = 0
    return AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr && size > 0
  }

  /// Built-in speakers and virtual or aggregate devices are never plugged in, so leave them out.
  private static func canBePluggedIn(_ id: AudioDeviceID) -> Bool {
    var addr = address(kAudioDevicePropertyTransportType)
    var transport: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &transport) == noErr else { return false }
    return ![kAudioDeviceTransportTypeBuiltIn, kAudioDeviceTransportTypeVirtual, kAudioDeviceTransportTypeAggregate]
      .contains(transport)
  }

  /// Output devices that can be plugged in or connected.
  static func outputDevices() -> [OutputDevice] {
    var addr = address(kAudioHardwarePropertyDevices)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(system, &addr, 0, nil, &size) == noErr else { return [] }
    var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
    guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &ids) == noErr else { return [] }
    return ids.compactMap { id in
      guard hasOutput(id), canBePluggedIn(id),
            let uid = string(id, kAudioDevicePropertyDeviceUID),
            let name = string(id, kAudioObjectPropertyName) else { return nil }
      return OutputDevice(id: id, uid: uid, name: name)
    }
  }

  static func defaultOutput() -> AudioDeviceID? {
    var addr = address(kAudioHardwarePropertyDefaultOutputDevice)
    var id: AudioDeviceID = 0
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    guard AudioObjectGetPropertyData(system, &addr, 0, nil, &size, &id) == noErr else { return nil }
    return id
  }

  /// Sets both the output for sound and the output for alerts and sound effects.
  static func setDefaultOutput(_ id: AudioDeviceID) {
    var device = id
    let size = UInt32(MemoryLayout<AudioDeviceID>.size)
    for selector in [kAudioHardwarePropertyDefaultOutputDevice, kAudioHardwarePropertyDefaultSystemOutputDevice] {
      var addr = address(selector)
      AudioObjectSetPropertyData(system, &addr, 0, nil, size, &device)
    }
  }

  /// Calls `handler` on the main queue whenever a device is connected or disconnected.
  static func onDevicesChanged(_ handler: @escaping () -> Void) {
    var addr = address(kAudioHardwarePropertyDevices)
    AudioObjectAddPropertyListenerBlock(system, &addr, .main) { _, _ in handler() }
  }
}
