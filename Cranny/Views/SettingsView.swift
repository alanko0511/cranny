import SwiftUI
import AppKit
import ServiceManagement

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            ChannelsSettingsView()
                .tabItem { Label("Channels", systemImage: "tv") }
            APIKeySettingsView()
                .tabItem { Label("API Key", systemImage: "key") }
            AboutSettingsView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 500, height: 440)
        // Bring the Settings window to the front — an accessory (LSUIElement) app
        // doesn't activate when Settings opens, so it can spawn behind other windows.
        .background(WindowActivator())
    }
}

/// Grabs the hosting NSWindow on appear and brings it forward, activating the app.
private struct WindowActivator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - General

struct GeneralSettingsView: View {
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var note: String?

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do { try LaunchAtLogin.setEnabled(newValue) }
                        catch { launchAtLogin = LaunchAtLogin.isEnabled }  // revert on failure
                        refreshNote()
                    }
                if let note {
                    Text(note).font(.caption).foregroundStyle(.secondary)
                }
            } header: {
                Text("General")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            launchAtLogin = LaunchAtLogin.isEnabled
            refreshNote()
        }
    }

    private func refreshNote() {
        note = LaunchAtLogin.requiresApproval
            ? "Approve Cranny in System Settings ▸ General ▸ Login Items."
            : nil
    }
}

// MARK: - Channels

struct ChannelsSettingsView: View {
    @Environment(ChannelStore.self) private var store
    @State private var showAdd = false

    var body: some View {
        Form {
            Section("Channels") {
                if store.channels.isEmpty {
                    Text("No channels yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(store.channels) { channel in
                    HStack(spacing: 10) {
                        AsyncImage(url: channel.thumbnailURL) { $0.resizable() } placeholder: {
                            Circle().fill(.quaternary)
                        }
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 1) {
                            Text(channel.title)
                            if let handle = channel.handle {
                                Text(handle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button(role: .destructive) {
                            store.remove(channel)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            Section {
                Button {
                    showAdd = true
                } label: {
                    Label("Add channel…", systemImage: "plus")
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showAdd) {
            AddChannelView(onClose: { showAdd = false })
                .environment(store)
        }
    }
}

// MARK: - API Key

struct APIKeySettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var key = ""
    @State private var status: String?

    var body: some View {
        Form {
            Section {
                SecureField("API key", text: $key)
                HStack {
                    Button("Save") { save() }
                        .disabled(key.isEmpty)
                    Button("Remove") { remove() }
                        .disabled(!appState.hasAPIKey)
                    Spacer()
                    if let status {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Link("How to create a free key →",
                     destination: URL(string: "https://console.cloud.google.com/apis/credentials")!)
                    .font(.caption)
            } header: {
                Text("YouTube Data API key")
            } footer: {
                Text("Stored securely in your macOS Keychain — never bundled or shared.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { key = appState.currentAPIKey() ?? "" }
    }

    private func save() {
        do { try appState.setAPIKey(key); status = "Saved ✓" }
        catch { status = "Error saving" }
    }

    private func remove() {
        do { try appState.clearAPIKey(); key = ""; status = "Removed" }
        catch { status = "Error removing" }
    }
}

// MARK: - About

struct AboutSettingsView: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "play.rectangle.on.rectangle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Cranny").font(.headline)
                        Text("Version \(version)").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text("Cranny plays videos through YouTube's official IFrame Player and lists "
                     + "them via the YouTube Data API. Playback data is shared with YouTube and "
                     + "subject to YouTube's Terms of Service & Google's Privacy Policy. Ads play "
                     + "normally and are never modified.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Section {
                Link("YouTube Terms of Service", destination: URL(string: "https://www.youtube.com/t/terms")!)
                Link("Google Privacy Policy", destination: URL(string: "https://policies.google.com/privacy")!)
                Link("YouTube API Services Terms", destination: URL(string: "https://developers.google.com/youtube/terms/api-services-terms-of-service")!)
            }
            .font(.caption)
        }
        .formStyle(.grouped)
    }
}
