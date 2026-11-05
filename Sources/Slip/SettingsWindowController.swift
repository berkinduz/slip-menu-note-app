import AppKit
import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
    case appearance, editor, capture, organization, data, about
    var id: String { rawValue }
    var title: String {
        switch self {
        case .appearance: "Appearance"
        case .editor: "Editor"
        case .capture: "Quick capture"
        case .organization: "Organization"
        case .data: "Data & sync"
        case .about: "About Slip"
        }
    }
    var symbol: String {
        switch self {
        case .appearance: "paintpalette"
        case .editor: "textformat"
        case .capture: "bolt"
        case .organization: "square.stack"
        case .data: "externaldrive.badge.icloud"
        case .about: "info.circle"
        }
    }
}

@MainActor
final class SettingsWindowController {
    let window: NSWindow
    private let workspace: Workspace

    init(workspace: Workspace) {
        self.workspace = workspace
        let window = SettingsWindow(
            contentRect: NSRect(x: 0, y: 0, width: 830, height: 680),
            styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false
        )
        self.window = window
        window.title = "Appearance"
        window.setAccessibilityLabel("Slip Settings")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        let hosting = NSHostingView(rootView: ThemedRoot(
            settings: workspace.settings,
            content: SettingsView(workspace: workspace) { [weak window] pane in window?.title = pane.title }
        ))
        hosting.sizingOptions = []
        window.contentView = hosting
        window.center()
        applyAppearance()
    }

    func show() {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func applyAppearance() {
        let style = SlipStyle(theme: workspace.settings.preferences.theme)
        window.appearance = style.appearance
        window.backgroundColor = style.canvasColor
    }
}

private final class SettingsWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) { close() }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection([.command, .control, .option, .shift]) == .command,
           event.charactersIgnoringModifiers?.lowercased() == "w" {
            close()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
