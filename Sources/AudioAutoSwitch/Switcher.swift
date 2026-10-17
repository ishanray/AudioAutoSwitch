import Foundation

/// Tracks connected output devices and switches to a chosen one when it is plugged in.
@MainActor
final class Switcher: ObservableObject {
  private static let defaultsKey = "autoSwitchDevices"

  @Published private(set) var devices: [OutputDevice] = []
  /// Device UID to name, so devices that are unplugged can still be listed.
  @Published private(set) var chosen: [String: String]

  init() {
    chosen = UserDefaults.standard.dictionary(forKey: Self.defaultsKey) as? [String: String] ?? [:]
    devices = AudioSystem.outputDevices()
    // Cover the case where a chosen device is already plugged in at launch.
    switchToChosen(among: devices)
    AudioSystem.onDevicesChanged { [weak self] in
      MainActor.assumeIsolated { self?.devicesChanged() }
    }
  }

  var unplugged: [(uid: String, name: String)] {
    let connected = Set(devices.map(\.uid))
    return chosen
      .filter { !connected.contains($0.key) }
      .map { (uid: $0.key, name: $0.value) }
      .sorted { $0.name < $1.name }
  }

  func isChosen(_ uid: String) -> Bool {
    chosen[uid] != nil
  }

  func setChosen(_ device: OutputDevice, _ on: Bool) {
    chosen[device.uid] = on ? device.name : nil
    save()
    if on { AudioSystem.setDefaultOutput(device.id) }
  }

  func forget(_ uid: String) {
    chosen[uid] = nil
    save()
  }

  private func devicesChanged() {
    let previous = Set(devices.map(\.uid))
    devices = AudioSystem.outputDevices()
    switchToChosen(among: devices.filter { !previous.contains($0.uid) })
  }

  private func switchToChosen(among candidates: [OutputDevice]) {
    guard let target = candidates.first(where: { isChosen($0.uid) }),
          AudioSystem.defaultOutput() != target.id else { return }
    AudioSystem.setDefaultOutput(target.id)
  }

  private func save() {
    UserDefaults.standard.set(chosen, forKey: Self.defaultsKey)
  }
}
