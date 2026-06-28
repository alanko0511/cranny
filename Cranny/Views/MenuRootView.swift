import SwiftUI

/// Root of the menu-bar popover. Routes between onboarding and the channel browser.
struct MenuRootView: View {
    @Environment(AppState.self) private var appState
    @Environment(ChannelStore.self) private var store

    var body: some View {
        if !appState.hasAPIKey || store.channels.isEmpty {
            OnboardingView()
        } else {
            ChannelBrowserView()
        }
    }
}
