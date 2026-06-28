import SwiftUI

/// The ▾ dropdown: a vertical, scrollable list of saved channels + footer actions.
struct ChannelSwitcherMenu: View {
    @Environment(ChannelStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(store.channels) { channel in
                        Button {
                            store.select(channel.id)
                            dismiss()
                        } label: {
                            HStack(spacing: 9) {
                                avatar(channel.thumbnailURL)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(channel.title)
                                        .font(.system(size: 13, weight: .semibold))
                                    if let handle = channel.handle {
                                        Text(handle)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer(minLength: 8)
                                if channel.id == store.selectedChannel?.id {
                                    Image(systemName: "checkmark")
                                        .font(.caption)
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 240)

            Divider()

            Button {
                dismiss()
                onAdd()
            } label: {
                Label("Add channel…", systemImage: "plus")
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            SettingsLink {
                Label("Manage channels…", systemImage: "gearshape")
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(6)
        .frame(width: 280)
    }

    private func avatar(_ url: URL?) -> some View {
        AsyncImage(url: url) { image in
            image.resizable()
        } placeholder: {
            Circle().fill(.quaternary)
        }
        .frame(width: 26, height: 26)
        .clipShape(Circle())
    }
}
