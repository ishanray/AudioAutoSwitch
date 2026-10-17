import ServiceManagement
import SwiftUI

@main
struct AudioAutoSwitchApp: App {
  @StateObject private var switcher = Switcher()

  var body: some Scene {
    MenuBarExtra {
      MenuContent(switcher: switcher)
    } label: {
      Image(systemName: "headphones")
        .accessibilityLabel("Audio Auto Switch")
    }
  }
}

struct MenuContent: View {
  @ObservedObject var switcher: Switcher
  @State private var openAtLogin = SMAppService.mainApp.status == .enabled

  var body: some View {
    Text("Switch to these when plugged in")
    if switcher.devices.isEmpty {
      Text("Plug in your headphones to choose them")
    }
    ForEach(switcher.devices) { device in
      Toggle(device.name, isOn: Binding(
        get: { switcher.isChosen(device.uid) },
        set: { switcher.setChosen(device, $0) }
      ))
    }

    if !switcher.unplugged.isEmpty {
      Divider()
      Text("Not plugged in")
      ForEach(switcher.unplugged, id: \.uid) { device in
        Toggle(device.name, isOn: Binding(
          get: { true },
          set: { if !$0 { switcher.forget(device.uid) } }
        ))
      }
    }

    Divider()
    Toggle("Open at Login", isOn: Binding(
      get: { openAtLogin },
      set: { setOpenAtLogin($0) }
    ))
    Button("Quit") { NSApplication.shared.terminate(nil) }
      .keyboardShortcut("q")
  }

  private func setOpenAtLogin(_ on: Bool) {
    do {
      if on {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
    } catch {
      NSLog("Open at Login change failed: \(error.localizedDescription)")
    }
    openAtLogin = SMAppService.mainApp.status == .enabled
  }
}
