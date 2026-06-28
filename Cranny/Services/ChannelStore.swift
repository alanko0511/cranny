import Foundation
import Observation

/// Holds the user's saved channels + current selection, persisted as JSON in
/// Application Support (sandbox-redirected to the app container).
@MainActor
@Observable
final class ChannelStore {
    private(set) var channels: [Channel] = []
    var selectedChannelID: String?

    private let fileURL: URL

    init() {
        let fm = FileManager.default
        let dir = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                               appropriateFor: nil, create: true))?
            .appendingPathComponent("com.alanko.cranny", isDirectory: true)
        if let dir {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            fileURL = dir.appendingPathComponent("channels.json")
        } else {
            fileURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("channels.json")
        }
        load()
    }

    var selectedChannel: Channel? {
        channels.first { $0.id == selectedChannelID } ?? channels.first
    }

    func add(_ channel: Channel) {
        if !channels.contains(where: { $0.id == channel.id }) {
            channels.append(channel)
        }
        selectedChannelID = channel.id   // switch to the newly added channel
        save()
    }

    func remove(_ channel: Channel) {
        channels.removeAll { $0.id == channel.id }
        if selectedChannelID == channel.id {
            selectedChannelID = channels.first?.id
        }
        save()
    }

    func select(_ id: String) {
        guard channels.contains(where: { $0.id == id }) else { return }
        selectedChannelID = id
        save()
    }

    // MARK: - Persistence

    private struct Persisted: Codable {
        var channels: [Channel]
        var selectedChannelID: String?
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let p = try? JSONDecoder().decode(Persisted.self, from: data) else { return }
        channels = p.channels
        selectedChannelID = p.selectedChannelID
    }

    private func save() {
        let p = Persisted(channels: channels, selectedChannelID: selectedChannelID)
        if let data = try? JSONEncoder().encode(p) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
