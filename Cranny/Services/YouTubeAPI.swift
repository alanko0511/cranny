import Foundation

/// Decodable DTOs for the YouTube Data API v3 responses + a tolerant JSON decoder.
enum YouTubeAPI {
    /// Fresh decoder per use (keeps it concurrency-safe under strict concurrency).
    /// Tolerates ISO-8601 with or without fractional seconds.
    static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { dec in
            let s = try dec.singleValueContainer().decode(String.self)
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = f.date(from: s) { return date }
            f.formatOptions = [.withInternetDateTime]
            if let date = f.date(from: s) { return date }
            throw DecodingError.dataCorruptedError(
                in: try dec.singleValueContainer(),
                debugDescription: "Bad ISO-8601 date: \(s)")
        }
        return d
    }
}

// MARK: - channels.list

struct ChannelListResponse: Decodable { let items: [ChannelItem]? }

struct ChannelItem: Decodable {
    let id: String
    let snippet: ChannelSnippet?
    let contentDetails: ChannelContentDetails?
}

struct ChannelSnippet: Decodable {
    let title: String
    let customUrl: String?
    let thumbnails: Thumbnails?
}

struct ChannelContentDetails: Decodable { let relatedPlaylists: RelatedPlaylists }
struct RelatedPlaylists: Decodable { let uploads: String }

// MARK: - playlistItems.list

struct PlaylistItemListResponse: Decodable {
    let items: [PlaylistItem]?
    let nextPageToken: String?
}

struct PlaylistItem: Decodable {
    let snippet: PlaylistItemSnippet
    let contentDetails: PlaylistItemContentDetails
}

struct PlaylistItemSnippet: Decodable {
    let title: String
    let publishedAt: Date
    let thumbnails: Thumbnails?
}

struct PlaylistItemContentDetails: Decodable {
    let videoId: String
    let videoPublishedAt: Date?
}

// MARK: - videos.list (durations)

struct VideoListResponse: Decodable { let items: [VideoItem]? }
struct VideoItem: Decodable {
    let id: String
    let contentDetails: VideoContentDetails
}
struct VideoContentDetails: Decodable { let duration: String }

// Full video detail (snippet + contentDetails) — used for play-by-URL.
struct VideoDetailResponse: Decodable { let items: [VideoDetailItem]? }
struct VideoDetailItem: Decodable {
    let id: String
    let snippet: VideoDetailSnippet
    let contentDetails: VideoContentDetails
}
struct VideoDetailSnippet: Decodable {
    let title: String
    let publishedAt: Date
    let thumbnails: Thumbnails?
}

// MARK: - Thumbnails (shared shape)

struct Thumbnails: Decodable {
    let `default`: Thumbnail?
    let medium: Thumbnail?
    let high: Thumbnail?
    let standard: Thumbnail?
    let maxres: Thumbnail?

    /// 320×180, always present — the right size for a list-row thumbnail.
    var rowThumbnail: URL? { (medium ?? high ?? `default`)?.url }
    /// Small square-ish image for a channel avatar.
    var avatar: URL? { (`default` ?? medium)?.url }
}

struct Thumbnail: Decodable {
    let url: URL
    let width: Int?
    let height: Int?
}
