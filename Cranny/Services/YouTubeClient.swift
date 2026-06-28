import Foundation

/// Stateless client for the YouTube Data API v3. Reads the API key from Keychain per call.
struct YouTubeClient {
    enum ClientError: LocalizedError {
        case missingAPIKey
        case http(Int, String?)
        case notFound
        case unsupportedInput(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "No API key set. Add your YouTube Data API key in Settings."
            case .http(let code, _):
                switch code {
                case 403: return "Request denied (403) — check the API key is valid and YouTube Data API v3 is enabled, or you may be out of quota."
                case 400: return "Bad request (400) — the API key may be invalid."
                case 404: return "Not found (404)."
                default:  return "Network error (\(code))."
                }
            case .notFound:
                return "No channel found for that input."
            case .unsupportedInput(let message):
                return message
            }
        }
    }

    private let base = URL(string: "https://www.googleapis.com/youtube/v3/")!

    // MARK: - Public API

    /// Resolve a user-pasted handle / URL / id into a `Channel` (with uploads playlist id).
    func resolveChannel(_ input: String) async throws -> Channel {
        switch normalize(input) {
        case .channelID(let id):  return try await channel(part: ["id": id])
        case .handle(let handle): return try await channel(part: ["forHandle": handle], handle: handle)
        case .unsupported(let message): throw ClientError.unsupportedInput(message)
        }
    }

    /// One page of a channel's uploads, newest first.
    func fetchUploads(playlistID: String, pageToken: String?) async throws -> (videos: [Video], nextPageToken: String?) {
        var query = ["part": "snippet,contentDetails", "playlistId": playlistID, "maxResults": "50"]
        if let pageToken { query["pageToken"] = pageToken }
        let response = try await get("playlistItems", query, as: PlaylistItemListResponse.self)
        let videos = (response.items ?? []).map { item in
            Video(
                id: item.contentDetails.videoId,
                title: item.snippet.title,
                publishedAt: item.contentDetails.videoPublishedAt ?? item.snippet.publishedAt,
                thumbnailURL: item.snippet.thumbnails?.rowThumbnail,
                durationLabel: nil
            )
        }
        .sorted { $0.publishedAt > $1.publishedAt }   // defensive: ensure newest-first
        return (videos, response.nextPageToken)
    }

    /// Parse a video id from a watch / youtu.be / shorts / embed URL, or a bare 11-char id.
    func parseVideoID(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.range(of: "^[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil {
            return trimmed
        }
        guard let url = URL(string: trimmed), let host = url.host else { return nil }
        if host.contains("youtu.be") {
            let id = url.lastPathComponent
            return id.count == 11 ? id : nil
        }
        if host.contains("youtube.com") {
            if let v = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "v" })?.value, v.count == 11 {
                return v
            }
            if let last = url.path.split(separator: "/").map(String.init).last, last.count == 11 {
                return last   // /shorts/<id>, /embed/<id>, /live/<id>
            }
        }
        return nil
    }

    /// Fetch a single video's metadata (for the play-by-URL preview + player title).
    func fetchVideo(id: String) async throws -> Video {
        let response = try await get("videos", ["part": "snippet,contentDetails", "id": id],
                                     as: VideoDetailResponse.self)
        guard let item = (response.items ?? []).first else { throw ClientError.notFound }
        return Video(
            id: item.id,
            title: item.snippet.title,
            publishedAt: item.snippet.publishedAt,
            thumbnailURL: item.snippet.thumbnails?.rowThumbnail,
            durationLabel: YTDuration.label(from: item.contentDetails.duration)
        )
    }

    /// Batched durations (≤50 ids/call) → [videoID: "m:ss"].
    func fetchDurations(videoIDs: [String]) async throws -> [String: String] {
        guard !videoIDs.isEmpty else { return [:] }
        let ids = videoIDs.prefix(50).joined(separator: ",")
        let response = try await get("videos", ["part": "contentDetails", "id": ids], as: VideoListResponse.self)
        var map: [String: String] = [:]
        for item in response.items ?? [] {
            if let label = YTDuration.label(from: item.contentDetails.duration) {
                map[item.id] = label
            }
        }
        return map
    }

    // MARK: - Private

    private func channel(part query: [String: String], handle: String? = nil) async throws -> Channel {
        var q = query
        q["part"] = "snippet,contentDetails"
        let response = try await get("channels", q, as: ChannelListResponse.self)
        guard let item = (response.items ?? []).first else { throw ClientError.notFound }
        let uploads = item.contentDetails?.relatedPlaylists.uploads
            ?? Channel.uploadsPlaylistID(forChannelID: item.id)
        let resolvedHandle = normalizedHandle(handle ?? item.snippet?.customUrl)
        return Channel(
            id: item.id,
            handle: resolvedHandle,
            title: item.snippet?.title ?? item.id,
            thumbnailURL: item.snippet?.thumbnails?.avatar,
            uploadsPlaylistId: uploads
        )
    }

    private func apiKey() throws -> String {
        guard let key = (try? Keychain.read()).flatMap({ $0 }), !key.isEmpty else {
            throw ClientError.missingAPIKey
        }
        return key
    }

    private func get<T: Decodable>(_ path: String, _ query: [String: String], as type: T.Type) async throws -> T {
        var comps = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
            + [URLQueryItem(name: "key", value: try apiKey())]

        Log.net.debug("GET \(path, privacy: .public)?\(query.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: "&"), privacy: .public)")

        var request = URLRequest(url: comps.url!)
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.http(-1, nil) }
        guard 200..<300 ~= http.statusCode else {
            let body = String(data: data, encoding: .utf8)
            Log.net.error("HTTP \(http.statusCode) \(path, privacy: .public): \(body ?? "", privacy: .public)")
            throw ClientError.http(http.statusCode, body)
        }
        return try YouTubeAPI.decoder.decode(T.self, from: data)
    }

    // MARK: - Input normalization

    private enum Resolved {
        case channelID(String)
        case handle(String)
        case unsupported(String)
    }

    private func normalize(_ input: String) -> Resolved {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Full youtube.com URL?
        if let url = URL(string: trimmed), let host = url.host, host.contains("youtube.com") {
            let parts = url.path.split(separator: "/").map(String.init)
            if let first = parts.first {
                if first == "channel", parts.count >= 2 { return .channelID(parts[1]) }
                if first.hasPrefix("@") { return .handle(String(first.dropFirst())) }
                if first == "c" || first == "user" {
                    return .unsupported("Legacy /\(first)/ URLs aren't supported. Open the channel on YouTube and copy its @handle.")
                }
                return .handle(first)   // bare /Something → try as a handle
            }
        }

        if trimmed.hasPrefix("@") { return .handle(String(trimmed.dropFirst())) }
        if trimmed.range(of: "^UC[A-Za-z0-9_-]{22}$", options: .regularExpression) != nil {
            return .channelID(trimmed)
        }
        if trimmed.range(of: "^[A-Za-z0-9._-]{2,}$", options: .regularExpression) != nil {
            return .handle(trimmed)   // bare word → try as a handle
        }
        return .unsupported("Paste a @handle or a youtube.com/channel/UC… URL.")
    }

    private func normalizedHandle(_ handle: String?) -> String? {
        guard let handle, !handle.isEmpty else { return nil }
        return handle.hasPrefix("@") ? handle : "@" + handle
    }
}
