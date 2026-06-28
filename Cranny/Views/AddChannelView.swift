import SwiftUI

/// Add a channel by @handle or /channel/UC… URL, with a live-resolved preview.
struct AddChannelView: View {
    @Environment(ChannelStore.self) private var store
    /// Closure the presenter provides to dismiss (works for both inline overlay + sheet).
    var onClose: () -> Void

    @State private var query = ""
    @State private var resolving = false
    @State private var resolved: Channel?
    @State private var error: String?

    private let client = YouTubeClient()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add a channel").font(.headline)

            TextField("@handle  or  youtube.com/channel/UC…", text: $query)
                .textFieldStyle(.roundedBorder)

            if resolving {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Resolving…").font(.caption).foregroundStyle(.secondary)
                }
            }

            if let resolved {
                HStack(spacing: 10) {
                    AsyncImage(url: resolved.thumbnailURL) { $0.resizable() } placeholder: {
                        Circle().fill(.quaternary)
                    }
                    .frame(width: 30, height: 30)
                    .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 1) {
                        Text(resolved.title).font(.system(size: 13, weight: .semibold))
                        if let handle = resolved.handle {
                            Text(handle).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Label("Found", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                .padding(9)
                .background(.quaternary.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 9))
            }

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Legacy /c/ and /user/ URLs aren't supported — copy the channel's @handle instead.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Cancel") { onClose() }
                Button("Add channel") {
                    if let resolved { store.add(resolved); onClose() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(resolved == nil)
            }
        }
        .padding(16)
        .frame(maxWidth: 360)
        .task(id: query) { await resolve() }   // re-runs (and cancels prior) on each keystroke
    }

    private func resolve() async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        resolved = nil
        error = nil
        guard q.count >= 2 else { return }

        // Debounce: if a new keystroke arrives, this task is cancelled before the sleep ends.
        try? await Task.sleep(nanoseconds: 400_000_000)
        if Task.isCancelled { return }

        resolving = true
        defer { resolving = false }
        do {
            let channel = try await client.resolveChannel(q)
            if Task.isCancelled { return }
            resolved = channel
        } catch {
            if Task.isCancelled { return }
            self.error = (error as? LocalizedError)?.errorDescription ?? "Couldn't find that channel."
        }
    }
}
