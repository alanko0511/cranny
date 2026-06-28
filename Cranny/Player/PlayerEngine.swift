import Foundation
import WebKit
import Observation
import AppKit

/// Forwards WKScriptMessages to a MainActor closure. WebKit delivers on the main thread,
/// so `assumeIsolated` is safe here.
final class ScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private let onMessage: @MainActor (WKScriptMessage) -> Void
    init(_ onMessage: @escaping @MainActor (WKScriptMessage) -> Void) { self.onMessage = onMessage }

    nonisolated func userContentController(_ userContentController: WKUserContentController,
                                           didReceive message: WKScriptMessage) {
        MainActor.assumeIsolated { onMessage(message) }
    }
}

/// Owns the WKWebView + JS bridge and exposes observable playback state.
/// The webview + IFrame page are created once; loading a video calls JS, not a page reload.
@MainActor
@Observable
final class PlayerEngine {
    enum PlaybackState: Int {
        case unstarted = -1, ended = 0, playing = 1, paused = 2, buffering = 3, cued = 5
    }

    private let host = "cranny.local"

    let webView: WKWebView

    private(set) var currentVideo: Video?
    private(set) var state: PlaybackState = .unstarted
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    private(set) var errorMessage: String?
    /// Whether the widget is in its expanded (full 16:9) layout. Driven by the controller.
    var isExpanded = false

    var isPlaying: Bool { state == .playing || state == .buffering }

    private var isReady = false
    private var pendingVideoID: String?

    init() {
        let controller = WKUserContentController()
        controller.addUserScript(WKUserScript(
            source: PlayerHTML.logBridgeJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))

        let config = WKWebViewConfiguration()
        config.userContentController = controller
        config.mediaTypesRequiringUserActionForPlayback = []   // allow autoplay (macOS)

        webView = WKWebView(frame: .zero, configuration: config)

        controller.add(ScriptMessageHandler { [weak self] message in
            self?.handle(message)
        }, name: "cranny")

        webView.loadHTMLString(PlayerHTML.page(origin: "https://\(host)"),
                               baseURL: URL(string: "https://\(host)/"))
    }

    // MARK: - Commands (Swift → JS)

    func load(video: Video) {
        currentVideo = video
        errorMessage = nil
        currentTime = 0
        duration = 0
        if isReady { eval("window.cranny.load('\(escape(video.id))')") }
        else { pendingVideoID = video.id }
    }

    func play()  { eval("window.cranny.play()") }
    func pause() { eval("window.cranny.pause()") }
    func stop()  { eval("window.cranny.stop()") }

    /// Stop playback and clear all state (so nothing reads as "now playing" after close).
    func unload() {
        stop()
        currentVideo = nil
        state = .unstarted
        currentTime = 0
        duration = 0
        errorMessage = nil
    }
    func seek(to seconds: Double) {
        currentTime = seconds
        eval("window.cranny.seek(\(seconds))")
    }

    func togglePlayPause() { isPlaying ? pause() : play() }

    func openCurrentOnYouTube() {
        guard let video = currentVideo else { return }
        NSWorkspace.shared.open(video.watchURL)
    }

    // MARK: - Events (JS → Swift)

    private func handle(_ message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let kind = body["kind"] as? String else { return }

        switch kind {
        case "log":
            let text = body["text"] as? String ?? ""
            switch body["level"] as? String {
            case "error": Log.playerJS.error("\(text, privacy: .public)")
            case "warn":  Log.playerJS.warning("\(text, privacy: .public)")
            default:      Log.playerJS.debug("\(text, privacy: .public)")
            }
        case "exception":
            Log.playerJS.fault("UNCAUGHT JS: \(body["text"] as? String ?? "", privacy: .public)")
        case "ready":
            isReady = true
            Log.player.info("player ready")
            if let pending = pendingVideoID {
                eval("window.cranny.load('\(escape(pending))')")
                pendingVideoID = nil
            }
        case "state":
            if let raw = body["state"] as? Int, let s = PlaybackState(rawValue: raw) { state = s }
            if let d = body["duration"] as? Double, d > 0 { duration = d }
        case "time":
            if let t = body["t"] as? Double { currentTime = t }
            if let d = body["d"] as? Double, d > 0 { duration = d }
        case "error":
            handleError(code: body["code"] as? Int ?? -1)
        default:
            break
        }
    }

    private func handleError(code: Int) {
        Log.player.error("player error code \(code)")
        switch code {
        case 101, 150:
            errorMessage = "The uploader disabled embedded playback for this video."
        case 100:
            errorMessage = "This video is unavailable (removed, private, or region-blocked)."
        case 2:
            errorMessage = "Invalid video."
        case 5:
            errorMessage = "Playback error. Try again."
        case 153:
            // Our config bug, not the video's — should not happen with the fake-https baseURL.
            Log.player.fault("Error 153: embed has no valid HTTP Referer — check baseURL/origin/Referrer-Policy")
            errorMessage = "Playback configuration error."
        default:
            errorMessage = "Playback failed (code \(code))."
        }
    }

    // MARK: - Helpers

    private func eval(_ js: String) {
        webView.evaluateJavaScript(js) { _, error in
            if let error { Log.player.error("evalJS failed: \(error.localizedDescription, privacy: .public)") }
        }
    }

    private func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "'", with: "\\'")
    }
}
