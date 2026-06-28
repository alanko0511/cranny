import SwiftUI

/// Shown in the popover before the app is usable (no API key, or no channels).
struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(ChannelStore.self) private var store

    var body: some View {
        VStack(spacing: 12) {
            Text("🪺")
                .font(.system(size: 40))
            Text("Welcome to Cranny")
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            SettingsLink {
                Text("Open Settings")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var message: String {
        if !appState.hasAPIKey {
            return "Add your free YouTube Data API key, then add a channel to start browsing."
        } else {
            return "Add a YouTube channel to start browsing its videos."
        }
    }
}
