import Foundation
import Observation

/// Loads + paginates one channel's uploads, merging in durations per page.
@MainActor
@Observable
final class VideoFeed {
    let channel: Channel
    private(set) var videos: [Video] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var errorMessage: String?

    private(set) var reachedEnd = false
    private var nextPageToken: String?
    private let client = YouTubeClient()

    init(channel: Channel) {
        self.channel = channel
    }

    func loadInitial() async {
        guard videos.isEmpty, !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            let page = try await client.fetchUploads(playlistID: channel.uploadsPlaylistId, pageToken: nil)
            videos = page.videos
            nextPageToken = page.nextPageToken
            reachedEnd = page.nextPageToken == nil
            await mergeDurations(for: page.videos)
        } catch {
            errorMessage = message(for: error)
        }
        isLoading = false
    }

    /// Loads the next page. Driven by the bottom sentinel's onAppear; guards prevent dupes.
    func loadMore() async {
        guard !reachedEnd, !isLoadingMore, !isLoading, let token = nextPageToken else { return }
        isLoadingMore = true
        do {
            let page = try await client.fetchUploads(playlistID: channel.uploadsPlaylistId, pageToken: token)
            let fresh = page.videos.filter { v in !videos.contains(where: { $0.id == v.id }) }
            videos.append(contentsOf: fresh)
            nextPageToken = page.nextPageToken
            reachedEnd = page.nextPageToken == nil
            await mergeDurations(for: fresh)
        } catch {
            errorMessage = message(for: error)
        }
        isLoadingMore = false
    }

    private func mergeDurations(for batch: [Video]) async {
        let ids = batch.map(\.id)
        guard let map = try? await client.fetchDurations(videoIDs: ids), !map.isEmpty else { return }
        for i in videos.indices {
            if let label = map[videos[i].id] { videos[i].durationLabel = label }
        }
    }

    private func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "Couldn't load videos."
    }
}
