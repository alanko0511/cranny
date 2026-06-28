import AppKit
import SwiftUI

/// App-lifetime delegate. Owns long-lived stores/controllers + the status item so they live
/// outside the transient SwiftUI view graph.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    let channelStore = ChannelStore()
    let playerController = PlayerWindowController()
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Belt-and-suspenders with LSUIElement: never show a Dock icon.
        NSApp.setActivationPolicy(.accessory)

        let controller = StatusBarController()
        controller.setRootView(
            MenuRootView()
                .environment(appState)
                .environment(channelStore)
                .environment(playerController)
                .frame(width: 360, height: 480)
        )
        statusBar = controller
    }
}
