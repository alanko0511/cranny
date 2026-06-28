import SwiftUI

/// The popover's main surface: channel header (avatar + handle + ▾) + video list.
struct ChannelBrowserView: View {
    @Environment(ChannelStore.self) private var store
    @Environment(PlayerWindowController.self) private var player
    @Environment(\.dismissPopover) private var dismissPopover
    @State private var feed: VideoFeed?
    @State private var showSwitcher = false
    @State private var showAdd = false
    @State private var showPlayURL = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .task(id: store.selectedChannel?.id) {
            guard let channel = store.selectedChannel else { feed = nil; return }
            let newFeed = VideoFeed(channel: channel)
            feed = newFeed
            await newFeed.loadInitial()
        }
        // Inline overlays — a .sheet doesn't host correctly inside a popover.
        .overlay {
            if showAdd {
                overlayBackground {
                    AddChannelView(onClose: { showAdd = false }).environment(store)
                }
            } else if showPlayURL {
                overlayBackground {
                    PlayByURLView(
                        onPlay: { video in
                            player.show(video: video)
                            showPlayURL = false
                            dismissPopover()
                        },
                        onClose: { showPlayURL = false }
                    )
                }
            }
        }
    }

    private func overlayBackground<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ZStack {
            Rectangle().fill(.regularMaterial).ignoresSafeArea()
            content()
        }
    }

    private var footer: some View {
        Button { showPlayURL = true } label: {
            Label("Play a video by URL…", systemImage: "link")
                .font(.system(size: 12))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Button { showSwitcher.toggle() } label: {
                HStack(spacing: 8) {
                    avatar
                    VStack(alignment: .leading, spacing: 1) {
                        Text(store.selectedChannel?.title ?? "Cranny")
                            .font(.system(size: 13.5, weight: .semibold))
                        if let handle = store.selectedChannel?.handle {
                            Text(handle).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showSwitcher, arrowEdge: .bottom) {
                ChannelSwitcherMenu(onAdd: { showAdd = true }).environment(store)
            }

            Spacer()

            Button { showAdd = true } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.plain)
            .help("Add channel")

            SettingsLink { Image(systemName: "gearshape") }
                .buttonStyle(.plain)
                .help("Settings")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var avatar: some View {
        AsyncImage(url: store.selectedChannel?.thumbnailURL) { $0.resizable() } placeholder: {
            Circle().fill(.quaternary)
        }
        .frame(width: 26, height: 26)
        .clipShape(Circle())
    }

    // MARK: - Content

    @ViewBuilder private var content: some View {
        if let feed {
            if feed.isLoading && feed.videos.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = feed.errorMessage, feed.videos.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(feed.videos) { video in
                            VideoRow(video: video, isPlaying: video.id == player.engine.currentVideo?.id)
                                .onTapGesture {
                                    player.show(video: video)
                                    dismissPopover()   // close the popover, reveal the player
                                }
                        }
                        // Bottom sentinel: triggers the next page when scrolled into view.
                        if !feed.reachedEnd {
                            ProgressView()
                                .controlSize(.small)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .onAppear { Task { await feed.loadMore() } }
                        }
                    }
                    .padding(6)
                }
            }
        } else {
            Color.clear
        }
    }
}
