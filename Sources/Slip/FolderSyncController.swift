import AppKit
import Observation
import SlipCore

private actor FolderSyncWorker {
    private var engines: [String: FolderSyncEngine] = [:]
    private func engine(directory: URL, stateURL: URL) -> FolderSyncEngine {
        let key = directory.absoluteString + "|" + stateURL.absoluteString
        if let existing = engines[key] { return existing }
        let engine = FolderSyncEngine(directory: directory, stateURL: stateURL)
        engines[key] = engine
        return engine
    }
    func synchronize(directory: URL, stateURL: URL, library: NoteLibrary) throws -> FolderSyncResult {
        try engine(directory: directory, stateURL: stateURL).synchronize(library)
    }
    func acknowledge(directory: URL, stateURL: URL, library: NoteLibrary) throws {
        try engine(directory: directory, stateURL: stateURL).acknowledge(library)
    }
}

@MainActor @Observable
final class FolderSyncController {
    private(set) var folder: URL?
    private(set) var isSyncing = false
    private(set) var lastCheckedAt: Date?
    private(set) var errorMessage: String?
    private(set) var conflictMessage: String?
    private(set) var isWaitingForDownload = false
    private var lastAcknowledgedLibrary: NoteLibrary?
    @ObservationIgnored private let notebook: Notebook
    @ObservationIgnored private let settings: PreferencesStore
    @ObservationIgnored private let worker = FolderSyncWorker()
    @ObservationIgnored private var timer: Task<Void, Never>?
    @ObservationIgnored private var configurationID = UUID()
    @ObservationIgnored private var holdsFolderAccess = false

    init(notebook: Notebook, settings: PreferencesStore) {
        self.notebook = notebook
        self.settings = settings
        if let bookmark = settings.preferences.syncFolderBookmark {
            do {
                var stale = false
                let url = try URL(resolvingBookmarkData: bookmark, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &stale)
                folder = url
                holdsFolderAccess = url.startAccessingSecurityScopedResource()
                if stale { settings.preferences.syncFolderBookmark = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil) }
            } catch { errorMessage = "Choose your sync folder again. \(error.localizedDescription)" }
        }
    }

    var status: String {
        if errorMessage != nil { return "Sync needs attention" }
        if isSyncing { return "Checking sync folder…" }
        if folder == nil { return "Sync is off" }
        if isWaitingForDownload { return "Waiting for iCloud Drive download…" }
        guard let lastAcknowledgedLibrary else { return "Ready to sync" }
        return notebook.library.notes == lastAcknowledgedLibrary.notes && notebook.library.folders == lastAcknowledgedLibrary.folders
            ? "Saved to sync folder" : "Changes waiting to sync"
    }

    func start() {
        timer?.cancel()
        timer = Task { [weak self] in
            while !Task.isCancelled {
                await self?.synchronize()
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
            }
        }
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    func chooseFolder() {
        let picker = NSOpenPanel()
        picker.title = "Choose a sync folder"
        picker.message = "Choose a folder in iCloud Drive. Select the same folder in Slip on your other Mac."
        picker.prompt = "Use this folder"
        picker.canChooseDirectories = true
        picker.canChooseFiles = false
        picker.canCreateDirectories = true
        picker.directoryURL = folder
        guard picker.runModal() == .OK, let url = picker.url else { return }
        do {
            let bookmark = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
            if holdsFolderAccess { folder?.stopAccessingSecurityScopedResource() }
            holdsFolderAccess = url.startAccessingSecurityScopedResource()
            settings.preferences.syncFolderBookmark = bookmark
            folder = url
            configurationID = UUID()
            lastCheckedAt = nil
            lastAcknowledgedLibrary = nil
            isWaitingForDownload = false
            errorMessage = nil
            conflictMessage = nil
            Task { await synchronize() }
        } catch { errorMessage = "Couldn’t use this folder. \(error.localizedDescription)" }
    }

    func disable() {
        configurationID = UUID()
        settings.preferences.syncFolderBookmark = nil
        if holdsFolderAccess { folder?.stopAccessingSecurityScopedResource() }
        holdsFolderAccess = false
        folder = nil
        lastCheckedAt = nil
        lastAcknowledgedLibrary = nil
        isWaitingForDownload = false
        errorMessage = nil
        conflictMessage = nil
    }

    func synchronize() async {
        guard let folder, !isSyncing, notebook.canWrite else { return }
        notebook.flush()
        guard notebook.saveState == .saved else {
            errorMessage = "Sync is waiting until your latest changes can be saved on this Mac."
            return
        }
        isSyncing = true
        let configuration = configurationID
        let snapshot = notebook.library
        let directory = folder.appendingPathComponent("Slip Sync", isDirectory: true).appendingPathComponent("Records", isDirectory: true)
        let path = folder.resolvingSymlinksInPath().standardizedFileURL.path
        let stateID: String
        if let existing = settings.preferences.syncFolderStateIDs[path] { stateID = existing }
        else {
            stateID = UUID().uuidString
            settings.preferences.syncFolderStateIDs[path] = stateID
        }
        let stateURL = notebook.directory.appendingPathComponent("sync-states", isDirectory: true).appendingPathComponent(stateID + ".json")
        defer { isSyncing = false }
        do {
            let result = try await worker.synchronize(directory: directory, stateURL: stateURL, library: snapshot)
            guard configuration == configurationID else { return }
            guard try notebook.applySynchronizedLibrary(result.library, basedOn: snapshot) else { return }
            try await worker.acknowledge(directory: directory, stateURL: stateURL, library: result.library)
            guard configuration == configurationID else { return }
            lastCheckedAt = .now
            lastAcknowledgedLibrary = result.library
            isWaitingForDownload = false
            errorMessage = nil
            if result.conflictCount > 0 { conflictMessage = "Conflicting edits were kept as separate notes marked “Conflict”." }
        } catch FolderSyncError.awaitingDownload {
            guard configuration == configurationID else { return }
            isWaitingForDownload = true
            errorMessage = nil
        } catch {
            guard configuration == configurationID else { return }
            errorMessage = "Your local notes are safe. Couldn’t update the sync folder. \(error.localizedDescription)"
        }
    }
}
