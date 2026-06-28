import AppKit
import SwiftUI

/// Owns the menu-bar status item: left-click toggles the popover (channel browser),
/// right-click shows a context menu (Quit).
@MainActor
final class StatusBarController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "play.rectangle.on.rectangle",
                                   accessibilityDescription: "Cranny")
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 360, height: 480)
        popover.delegate = self
    }

    /// Sets the SwiftUI content (with its environment + a popover-close action injected).
    func setRootView(_ view: some View) {
        popover.contentViewController = NSHostingController(
            rootView: view.environment(\.dismissPopover, { [weak self] in self?.closePopover() })
        )
    }

    func closePopover() { popover.performClose(nil) }

    @objc private func handleClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)   // so text fields in the popover get focus
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showMenu() {
        guard let button = statusItem.button else { return }
        let menu = NSMenu()
        menu.addItem(withTitle: "Quit Cranny",
                     action: #selector(NSApplication.terminate(_:)),
                     keyEquivalent: "q")
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 5), in: button)
    }
}
