import SwiftUI

@main
struct CrannyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // The menu-bar status item + popover are managed by AppDelegate/StatusBarController.
        // This app only needs the Settings scene here.
        Settings {
            SettingsView()
                .environment(appDelegate.appState)
                .environment(appDelegate.channelStore)
        }
    }
}
