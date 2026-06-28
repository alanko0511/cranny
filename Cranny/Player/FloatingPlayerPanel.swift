import AppKit

/// Borderless, non-activating, always-on-top panel for the corner player.
/// Key config is set at init (especially `.nonactivatingPanel`, which must be in the
/// styleMask at construction or the WindowServer activation tag won't update).
final class FloatingPlayerPanel: NSPanel {
    init(contentSize: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        becomesKeyOnlyIfNeeded = true     // grab keyboard only when a control needs it
        hidesOnDeactivate = false         // stay visible when the user switches apps

        isMovableByWindowBackground = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        animationBehavior = .utilityWindow
        isReleasedWhenClosed = false      // keep the instance alive across show/hide
    }

    // Borderless/non-activating panels default to canBecomeKey=false; allow it for controls.
    override var canBecomeKey: Bool { true }
}
