import AppKit

@main enum SlipApplication {
    @MainActor static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: PanelController?
    private var shortcut: GlobalShortcut?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let arguments = ProcessInfo.processInfo.arguments
        let directory: URL
        if let index = arguments.firstIndex(of: "--data-dir"), arguments.indices.contains(index + 1) {
            directory = URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
        } else {
            directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Slip", isDirectory: true)
        }
        let workspace = Workspace(directory: directory)
        let controller = PanelController(workspace: workspace)
        self.controller = controller
        shortcut = GlobalShortcut { [weak controller] in controller?.toggle() }
        workspace.hotKeyAvailable = shortcut?.isRegistered ?? false
        DispatchQueue.main.async { controller.show() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        controller?.show()
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let notebook = controller?.workspace.notebook else { return .terminateNow }
        notebook.flush()
        guard notebook.canWrite, notebook.saveState == .failed else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "Your latest changes haven’t been saved."
        alert.informativeText = "Keep Slip open to try again, or quit and lose the unsaved changes."
        alert.addButton(withTitle: "Keep open")
        alert.addButton(withTitle: "Quit without saving")
        return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) {
        shortcut?.invalidate()
        controller?.cleanUp()
    }
}
