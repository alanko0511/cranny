import Foundation

/// A saved YouTube channel the user browses.
struct Channel: Codable, Identifiable, Hashable {
    /// The `UC…` channel id.
    let id: String
    /// `@handle` if known (used for display + the link-back to YouTube).
    var handle: String?
    var title: String
    var thumbnailURL: URL?
    /// The `UU…` uploads playlist id (channel id with the 2nd char flipped C→U).
    var uploadsPlaylistId: String

    /// Derive the uploads playlist id from a channel id (`UC…` → `UU…`).
    /// Reliable in practice but undocumented — prefer the value from the API when available.
    static func uploadsPlaylistID(forChannelID channelID: String) -> String {
        guard channelID.hasPrefix("UC"), channelID.count > 2 else { return channelID }
        return "UU" + channelID.dropFirst(2)
    }
}
