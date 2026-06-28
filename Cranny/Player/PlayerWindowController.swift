import AppKit
import SwiftUI
import Observation
import QuartzCore

/// Owns the floating panel + the player engine. Held by AppDelegate for the app's lifetime.
@MainActor
@Observable
final class PlayerWindowController {
    let engine = PlayerEngine()

    private var panel: FloatingPlayerPanel?
    private var collapseWork: DispatchWorkItem?
    private var isAnimating = false
    private let collapsedSize = NSSize(width: 340, height: 90)
    private let expandedSize = NSSize(width: 380, height: 380 * 9 / 16 + 76)
    private static let originKey = "CrannyPlayerOrigin"

    /// Load a video into the player, creating/showing the panel.
    func show(video: Video) {
        let panel = panel ?? makePanel()
        self.panel = panel
        engine.load(video: video)
        if !panel.isVisible { positionAtBottomRight(panel) }
        panel.orderFrontRegardless()      // show WITHOUT activating the app
    }

    func hide() {
        engine.unload()                   // stop + clear state (no lingering "now playing")
        panel?.orderOut(nil)
    }

    /// Hover handler with hysteresis: expand immediately, collapse after a short cancellable
    /// delay. This absorbs the spurious exit/enter events the resize itself generates, so the
    /// widget can't fight between states.
    private func handleHover(_ hovering: Bool) {
        collapseWork?.cancel()
        if hovering {
            setExpanded(true)
        } else {
            // Don't trust the exit event — the resize emits spurious ones. Re-check the actual
            // pointer geometry after a short delay and only collapse if truly outside.
            let work = DispatchWorkItem { [weak self] in
                guard let self, let panel = self.panel else { return }
                if !panel.frame.contains(NSEvent.mouseLocation) { self.setExpanded(false) }
            }
            collapseWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
        }
    }

    /// Resize between resting (audio bar) and expanded (full 16:9), anchored to the
    /// bottom-right corner. Animated, but hover events are ignored while animating (the
    /// `isAnimating` guard) so the panel's moving edges can't trigger a state fight; the
    /// real mouse position is reconciled when the animation completes.
    private func setExpanded(_ expanded: Bool) {
        guard let panel, engine.isExpanded != expanded, !isAnimating else { return }
        engine.isExpanded = expanded
        let target = expanded ? expandedSize : collapsedSize
        let old = panel.frame
        let newFrame = NSRect(x: old.maxX - target.width, y: old.minY,
                              width: target.width, height: target.height)

        isAnimating = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(newFrame, display: true)
        }, completionHandler: { [weak self] in
            self?.isAnimating = false
            self?.reconcileHoverState()
        })
    }

    /// After an animation, the mouse may have entered/left while we were ignoring events.
    /// Correct the state against the actual pointer location.
    private func reconcileHoverState() {
        guard let panel else { return }
        let inside = panel.frame.contains(NSEvent.mouseLocation)
        if inside != engine.isExpanded { setExpanded(inside) }
    }

    private func makePanel() -> FloatingPlayerPanel {
        let panel = FloatingPlayerPanel(contentSize: collapsedSize)

        let hosting = NSHostingView(rootView: PlayerView(
            engine: engine,
            onClose: { [weak self] in self?.hide() }
        ))
        hosting.translatesAutoresizingMaskIntoConstraints = false

        let container = HoverTrackingView()
        container.onHover = { [weak self] hovering in self?.handleHover(hovering) }
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.masksToBounds = true
        container.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        panel.contentView = container

        // Remember where the user parks it (only the resting/collapsed origin).
        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: panel, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let panel = self.panel, !self.engine.isExpanded else { return }
                UserDefaults.standard.set([panel.frame.origin.x, panel.frame.origin.y],
                                          forKey: Self.originKey)
            }
        }
        return panel
    }

    /// Restore the saved resting position if it's still on a visible screen; else bottom-right.
    private func positionAtBottomRight(_ panel: NSPanel) {
        let size = panel.frame.size
        if let saved = UserDefaults.standard.array(forKey: Self.originKey) as? [Double], saved.count == 2 {
            let origin = NSPoint(x: saved[0], y: saved[1])
            let frame = NSRect(origin: origin, size: size)
            if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) {
                panel.setFrameOrigin(origin)
                return
            }
        }
        guard let screen = NSScreen.main else { return }
        let margin: CGFloat = 24
        let visible = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: visible.maxX - size.width - margin,
                                     y: visible.minY + margin))
    }
}
