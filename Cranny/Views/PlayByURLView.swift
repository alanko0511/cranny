import SwiftUI

/// Inline overlay to paste a video URL/id, preview it, then play it immediately.
struct PlayByURLView: View {
    var onPlay: (Video) -> Void
    var onClose: () -> Void

    @State private var query = ""
    @State private var resolving = false
    @State private var preview: Video?
    @State private var error: String?

    private let client = YouTubeClient()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Play a video by URL").font(.headline)

            TextField("youtube.com/watch?v=…  or  youtu.be/…", text: $query)
                .textFieldStyle(.roundedBorder)

            if resolving {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Looking up…").font(.caption).foregroundStyle(.secondary)
                }
            }

            if let preview {
                HStack(spacing: 10) {
                    AsyncImage(url: preview.thumbnailURL) { $0.resizable().aspectRatio(contentMode: .fill) } placeholder: {
                        Rectangle().fill(.quaternary)
                    }
                    .frame(width: 72, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    Text(preview.title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                .padding(9)
                .background(.quaternary.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 9))
            }

            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button("Cancel") { onClose() }
                Button("Play") {
                    if let preview { onPlay(preview) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(preview == nil)
            }
        }
        .padding(16)
        .frame(maxWidth: 360)
        .task(id: query) { await resolve() }
    }

    private func resolve() async {
        preview = nil
        error = nil
        guard let id = client.parseVideoID(query) else {
            if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                error = "Paste a YouTube video link or 11-character id."
            }
            return
        }

        try? await Task.sleep(nanoseconds: 350_000_000)   // debounce
        if Task.isCancelled { return }

        resolving = true
        defer { resolving = false }
        do {
            let video = try await client.fetchVideo(id: id)
            if Task.isCancelled { return }
            preview = video
        } catch {
            if Task.isCancelled { return }
            self.error = (error as? LocalizedError)?.errorDescription ?? "Couldn't find that video."
        }
    }
}
