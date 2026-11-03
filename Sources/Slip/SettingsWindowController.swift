import AppKit
import SwiftUI

enum SettingsPane: String, CaseIterable {
    case appearance, writing, about

    var title: String {
        switch self {
        case .appearance: "Appearance"
        case .writing: "Writing"
        case .about: "About"
        }
    }
    var symbol: String {
        switch self {
        case .appearance: "paintpalette"
        case .writing: "text.alignleft"
        case .about: "info.circle"
        }
    }
    var identifier: NSToolbarItem.Identifier { .init("slip.settings.\(rawValue)") }
}

@MainActor
final class SettingsWindowController: NSObject, NSToolbarDelegate {
    let window: NSWindow
    private let workspace: Workspace
    private var pane: SettingsPane = .appearance

    init(workspace: Workspace) {
        self.workspace = workspace
        let window = SettingsWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 560),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        self.window = window
        super.init()
        window.title = "Slip Settings"
        window.setAccessibilityLabel("Slip Settings")
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.center()
        let toolbar = NSToolbar(identifier: "slip.settings.toolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.allowsUserCustomization = false
        toolbar.selectedItemIdentifier = pane.identifier
        window.toolbar = toolbar
        window.toolbarStyle = .preference
        updateContent()
        applyAppearance()
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func applyAppearance() {
        let style = SlipStyle(theme: workspace.settings.preferences.theme)
        window.appearance = style.appearance
        window.backgroundColor = style.canvasColor
    }

    private func updateContent() {
        window.title = pane.title
        let hosting = NSHostingView(rootView: ThemedRoot(
            settings: workspace.settings,
            content: SettingsView(workspace: workspace, pane: pane)
        ))
        hosting.sizingOptions = []
        window.contentView = hosting
        window.setContentSize(NSSize(width: 520, height: 560))
    }

    @objc private func selectPane(_ sender: NSToolbarItem) {
        guard let selected = SettingsPane.allCases.first(where: { $0.identifier == sender.itemIdentifier }) else { return }
        pane = selected
        window.toolbar?.selectedItemIdentifier = selected.identifier
        updateContent()
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        SettingsPane.allCases.map(\.identifier)
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        SettingsPane.allCases.map(\.identifier)
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        SettingsPane.allCases.map(\.identifier)
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        guard let pane = SettingsPane.allCases.first(where: { $0.identifier == identifier }) else { return nil }
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = pane.title
        item.paletteLabel = pane.title
        item.image = NSImage(systemSymbolName: pane.symbol, accessibilityDescription: pane.title)
        item.target = self
        item.action = #selector(selectPane(_:))
        return item
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
