import Foundation

/// A video in a channel's uploads list.
struct Video: Identifiable, Hashable {
    let id: String              // YouTube video id
    let title: String
    let publishedAt: Date
    let thumbnailURL: URL?
    var durationLabel: String?  // filled in after the batched videos.list fetch

    /// Canonical YouTube watch URL — used for the ToS link-back / fallback.
    var watchURL: URL { URL(string: "https://www.youtube.com/watch?v=\(id)")! }
}
