import SwiftUI

/// The floating audio-widget: tiny live video + transport when resting, full 16:9 when expanded.
/// Layout follows `engine.isExpanded` (driven by the controller on hover).
struct PlayerView: View {
    var engine: PlayerEngine
    var onClose: () -> Void

    var body: some View {
        Group {
            if engine.isExpanded {
                VStack(spacing: 0) {
                    videoArea.frame(maxWidth: .infinity).frame(height: expandedVideoHeight)
                    transport
                }
            } else {
                HStack(spacing: 0) {
                    videoArea.frame(width: 132, height: 74)
                    transport
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private let expandedVideoHeight: CGFloat = 380 * 9 / 16   // panel is 380 wide when expanded

    private var videoArea: some View {
        ZStack {
            Color.black
            PlayerVideoView(webView: engine.webView)
            if let error = engine.errorMessage {
                VStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Button("Open on YouTube") { engine.openCurrentOnYouTube() }
                        .font(.caption2)
                }
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black.opacity(0.85))
            }
        }
    }

    private var transport: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(engine.currentVideo?.title ?? "—")
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Button { engine.togglePlayPause() } label: {
                    Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 11))
                        .frame(width: 14)
                }
                .buttonStyle(.plain)

                Slider(value: scrubBinding, in: 0...max(engine.duration, 1))
                    .controlSize(.mini)

                Text("\(format(engine.currentTime)) / \(format(engine.duration))")
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var scrubBinding: Binding<Double> {
        Binding(get: { engine.currentTime }, set: { engine.seek(to: $0) })
    }

    private func format(_ t: Double) -> String {
        guard t.isFinite, t >= 0 else { return "0:00" }
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
