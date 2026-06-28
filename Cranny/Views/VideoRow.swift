import SwiftUI

struct VideoRow: View {
    let video: Video
    let isPlaying: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            thumbnail
            VStack(alignment: .leading, spacing: 3) {
                Text(video.title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .lineLimit(2)
                HStack(spacing: 4) {
                    if isPlaying {
                        Text("Now playing")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                        Text("·").foregroundStyle(.secondary).font(.caption2)
                    }
                    Text(video.publishedAt, format: .relative(presentation: .named))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(7)
        .background(isPlaying ? Color.accentColor.opacity(0.18) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .contentShape(Rectangle())
    }

    private var thumbnail: some View {
        ZStack(alignment: .bottomTrailing) {
            AsyncImage(url: video.thumbnailURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(.quaternary)
            }
            .frame(width: 120, height: 67.5)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 6))

            if let duration = video.durationLabel {
                Text(duration)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.black.opacity(0.78))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(4)
            }
        }
    }
}
