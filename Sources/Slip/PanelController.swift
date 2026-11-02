import AppKit
import SwiftUI
import SlipCore
import Observation

@MainActor final class CapturePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor final class PanelController: NSObject, NSWindowDelegate, NSMenuItemValidation {
    let workspace: Workspace
    let panel: CapturePanel
    private let statusItem: NSStatusItem
    private var globalMouseMonitor: Any?
    private var localMonitor: Any?
    private var activationObserver: NSObjectProtocol?
    private var settingsController: SettingsWindowController?

    init(workspace: Workspace) {
        self.workspace = workspace
        panel = CapturePanel(contentRect: NSRect(x: 0, y: 0, width: workspace.sidebarVisible ? 712 : 500, height: 480), styleMask: [.borderless, .nonactivatingPanel, .resizable], backing: .buffered, defer: false)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        panel.delegate = self
        panel.title = "slip — quick notes"
        panel.identifier = NSUserInterfaceItemIdentifier("SlipCapturePanel")
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.animationBehavior = .utilityWindow
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.minSize = NSSize(width: 380, height: 420)
        panel.maxSize = NSSize(width: 1300, height: 1100)
        panel.contentView = NSHostingView(rootView: ThemedRoot(settings: workspace.settings, content: ContentView(workspace: workspace)))
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 13
        panel.contentView?.layer?.masksToBounds = true
        panel.setAccessibilityLabel("slip quick notes")

        if let button = statusItem.button {
            let image = SlipMarkImage.image()
            image.size = NSSize(width: 19, height: 19)
            button.image = image
            button.toolTip = "slip · quick notes (⌃⌥n)"
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.setAccessibilityLabel("slip quick notes")
        }

        workspace.onDismiss = { [weak self] in self?.dismiss() }
        workspace.onResize = { [weak self] expanded in self?.resizeSidebar(expanded) }
        installMonitors()
        workspace.onSettings = { [weak self] in self?.showSettings() }
        NSApp.mainMenu = buildMainMenu()
        applyAppearance()
        observeTheme()
    }

    func toggle() { panel.isVisible ? dismiss() : show() }

    func show(newNote: Bool = false) {
        if newNote { workspace.newNote() }
        if !panel.isVisible { positionNearMenuBar() }
        panel.makeKeyAndOrderFront(nil)
        statusItem.button?.highlight(true)
        workspace.focusBody()
    }

    func dismiss() {
        (panel.firstResponder as? SourceTextView)?.hideSlashCommands()
        (panel.firstResponder as? SourceTextView)?.closeLinkEditor()
        workspace.notebook.flush()
        panel.orderOut(nil)
        statusItem.button?.highlight(false)
    }

    private func showSettings() {
        dismiss()
        if settingsController == nil { settingsController = SettingsWindowController(workspace: workspace) }
        settingsController?.show()
    }

    private func applyAppearance() {
        let style = SlipStyle(theme: workspace.settings.preferences.theme)
        if panel.appearance?.name != style.appearance?.name { panel.appearance = style.appearance }
        settingsController?.applyAppearance()
    }

    private func observeTheme() {
        withObservationTracking {
            _ = workspace.settings.preferences.theme
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.applyAppearance()
                self?.observeTheme()
            }
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool { dismiss(); return false }

    func cleanUp() {
        workspace.notebook.flush()
        if let globalMouseMonitor { NSEvent.removeMonitor(globalMouseMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
    }

    private func positionNearMenuBar() {
        let buttonWindow = statusItem.button?.window
        let screen = buttonWindow?.screen ?? NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main
        guard let screen else { return }
        let visible = screen.visibleFrame
        var frame = panel.frame
        frame.size.width = min(frame.width, visible.width - 24)
        frame.size.height = min(frame.height, visible.height - 24)
        if let button = statusItem.button, let buttonWindow {
            let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
            frame.origin.x = buttonRect.maxX - frame.width + 8
            frame.origin.y = buttonRect.minY - frame.height - 9
        } else {
            frame.origin.x = visible.maxX - frame.width - 16
            frame.origin.y = visible.maxY - frame.height - 12
        }
        frame.origin.x = min(max(frame.minX, visible.minX + 12), visible.maxX - frame.width - 12)
        frame.origin.y = min(max(frame.minY, visible.minY + 12), visible.maxY - frame.height - 8)
        panel.setFrame(frame, display: false)
    }

    private func resizeSidebar(_ expanded: Bool) {
        let old = panel.frame
        let width = expanded ? max(712, old.width + 212) : max(440, old.width - 212)
        panel.minSize = NSSize(width: expanded ? 632 : 380, height: 440)
        var frame = NSRect(x: old.maxX - width, y: old.minY, width: width, height: old.height)
        if let visible = panel.screen?.visibleFrame {
            frame.size.width = min(frame.width, visible.width - 24)
            frame.origin.x = min(max(frame.origin.x, visible.minX + 12), visible.maxX - frame.width - 12)
        }
        panel.setFrame(frame, display: true, animate: false)
    }

    private func dismissIfAllowed() {
        guard panel.isVisible, !workspace.keepOpen, panel.attachedSheet == nil,
              !workspace.showTags, !workspace.isEditingLink, !workspace.showGuide, !workspace.confirmEmptyTrash,
              workspace.operationError == nil else { return }
        dismiss()
    }

    private func installMonitors() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.dismissIfAllowed() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] event in
            let consumed = MainActor.assumeIsolated {
                guard let self else { return false }
                if event.type == .keyDown { return self.handleKey(event) == nil }
                if let window = event.window, window !== self.panel, window !== self.statusItem.button?.window, window.parent !== self.panel {
                    self.dismissIfAllowed()
                }
                return false
            }
            return consumed ? nil : event
        }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            let processID = (notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
            MainActor.assumeIsolated {
                if processID == ProcessInfo.processInfo.processIdentifier { return }
                self?.dismissIfAllowed()
            }
        }
    }

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        guard panel.isVisible, panel.isKeyWindow, panel.attachedSheet == nil else { return event }
        if event.keyCode == 53 {
            if let editor = panel.firstResponder as? SourceTextView, editor.dismissSlashCommands() { return nil }
            if workspace.showTags { workspace.showTags = false }
            else if workspace.showGuide { workspace.showGuide = false }
            else { dismiss() }
            return nil
        }
        guard event.modifierFlags.contains(.command) else { return event }
        let shift = event.modifierFlags.contains(.shift)
        let key = ShortcutKey.canonical(event.charactersIgnoringModifiers ?? "")
        let formattingKeys: Set<String> = shift ? ["h", "l", "t", "m"] : ["b", "i", "k", "e"]
        if formattingKeys.contains(key), !canFormatBody { return event }
        switch (key, shift) {
        case ("n", false): workspace.newNote()
        case ("f", false): workspace.search()
        case ("b", false): formatBody(.bold)
        case ("i", false): formatBody(.italic)
        case ("k", false): formatBody(.link)
        case ("e", false): formatBody(.code)
        case ("h", true): formatBody(.heading)
        case ("l", true): formatBody(.bullet)
        case ("t", true): formatBody(.task)
        case ("m", true): formatBody(.highlight)
        case ("\\", false), ("s", true): workspace.toggleSidebar()
        case ("s", false): workspace.notebook.flush()
        case (",", false): showSettings()
        case ("w", false): dismiss()
        case ("q", false): NSApp.terminate(nil)
        default: return event
        }
        return nil
    }

    private var canFormatBody: Bool {
        panel.firstResponder is SourceTextView && workspace.notebook.selectedNote?.deletedAt == nil
    }

    private func formatBody(_ action: MarkdownAction) {
        guard canFormatBody else { return }
        (panel.firstResponder as? SourceTextView)?.format(action)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if let name = menuItem.representedObject as? String, MarkdownAction(rawValue: name) != nil {
            return canFormatBody
        }
        return true
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        if let event = NSApp.currentEvent, event.type == .rightMouseUp, let button = statusItem.button {
            NSMenu.popUpContextMenu(buildStatusMenu(), with: event, for: button)
        } else { toggle() }
    }

    @objc private func menuAction(_ sender: NSMenuItem) {
        switch sender.representedObject as? String {
        case "open": show()
        case "new": show(newNote: true)
        case "close":
            if let keyWindow = NSApp.keyWindow, keyWindow !== panel { keyWindow.performClose(nil) }
            else { dismiss() }
        case "search": show(); workspace.search()
        case "export": workspace.exportNote()
        case "copyMarkdown": workspace.copyMarkdown()
        case "sidebar": workspace.toggleSidebar()
        case "keepOpen": workspace.keepOpen.toggle()
        case "guide": show(); workspace.showGuide = true
        case "folder": workspace.revealStorage()
        case "settings": showSettings()
        case "quit": NSApp.terminate(nil)
        case let name?: if let action = MarkdownAction(rawValue: name) { formatBody(action) }
        default: break
        }
    }

    private func item(_ title: String, _ action: String, key: String = "", shift: Bool = false) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(menuAction(_:)), keyEquivalent: key)
        item.target = self; item.representedObject = action
        item.keyEquivalentModifierMask = shift ? [.command, .shift] : .command
        return item
    }

    private func buildStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(item("open slip", "open"))
        menu.addItem(item("new note", "new", key: "n"))
        menu.addItem(.separator())
        let keep = item("keep open when switching apps", "keepOpen")
        keep.state = workspace.keepOpen ? .on : .off
        menu.addItem(keep)
        menu.addItem(item("settings…", "settings", key: ","))
        menu.addItem(item("keyboard shortcuts", "guide"))
        menu.addItem(item("show notes folder", "folder"))
        menu.addItem(.separator())
        menu.addItem(item("quit slip", "quit", key: "q"))
        return menu
    }

    private func buildMainMenu() -> NSMenu {
        let main = NSMenu()
        func submenu(_ title: String) -> NSMenu {
            let root = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let menu = NSMenu(title: title); root.submenu = menu; main.addItem(root); return menu
        }
        let app = submenu("slip")
        app.addItem(item("settings…", "settings", key: ","))
        app.addItem(item("keyboard shortcuts", "guide"))
        app.addItem(.separator())
        app.addItem(NSMenuItem(title: "hide slip", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        app.addItem(item("quit slip", "quit", key: "q"))
        let file = submenu("file")
        file.addItem(item("new note", "new", key: "n"))
        file.addItem(item("export markdown…", "export"))
        file.addItem(item("close", "close", key: "w"))
        let edit = submenu("edit")
        for (title, selector, key, shift) in [("undo", "undo:", "z", false), ("redo", "redo:", "z", true), ("cut", "cut:", "x", false), ("copy", "copy:", "c", false), ("paste", "paste:", "v", false), ("select all", "selectAll:", "a", false)] {
            let command = NSMenuItem(title: title, action: Selector(selector), keyEquivalent: key)
            command.keyEquivalentModifierMask = shift ? [.command, .shift] : .command
            edit.addItem(command)
        }
        edit.addItem(item("find a note", "search", key: "f"))
        let format = submenu("format")
        format.addItem(item("bold", "bold", key: "b"))
        format.addItem(item("italic", "italic", key: "i"))
        format.addItem(item("highlight", "highlight", key: "m", shift: true))
        format.addItem(item("heading", "heading", key: "h", shift: true))
        format.addItem(item("bullet list", "bullet", key: "l", shift: true))
        format.addItem(item("task list", "task", key: "t", shift: true))
        format.addItem(item("link", "link", key: "k"))
        format.addItem(item("code", "code", key: "e"))
        let view = submenu("view")
        view.addItem(item("toggle sidebar", "sidebar", key: "s", shift: true))
        view.addItem(item("keep open when switching apps", "keepOpen"))
        return main
    }
}
