import AppKit
import Observation
import SlipCore
import UniformTypeIdentifiers

enum InputFocus { case body, title, search }

@MainActor @Observable
final class Workspace {
    let notebook: Notebook
    let settings: PreferencesStore
    let editorSession: EditorSessionStore
    let sync: FolderSyncController
    let updates: UpdateController
    let loginItem: LoginItemController
    let backupStore: LibraryBackupStore
    var backups: [LibraryBackup] = []
    var backupToRestore: URL?
    var settingsPane: SettingsPane = .appearance
    var query = ""
    var filter: NoteFilter = .all
    var sidebarVisible = false
    var keepOpen: Bool {
        get { settings.preferences.keepOpen }
        set { settings.preferences.keepOpen = newValue }
    }
    var showGuide = false
    var showTags = false
    var showTagBrowser = false
    var showFolderBrowser = false
    var folderPrompt: FolderPrompt?
    var folderToRemove: UUID?
    var isEditingLink = false
    var confirmEmptyTrash = false
    var titleRequest = UUID()
    var focusRequest = UUID()
    var inputFocus: InputFocus = .body
    var searchRequest: UUID?
    var searchRevealRequest: UUID?
    var hotKeyAvailable = true
    var transientMessage: String?
    var undoTrashID: UUID?
    var operationError: String?
    @ObservationIgnored var onDismiss: (() -> Void)?
    @ObservationIgnored var onResize: ((Bool) -> Void)?
    @ObservationIgnored var onSettings: (() -> Void)?
    @ObservationIgnored private var messageTask: Task<Void, Never>?
    @ObservationIgnored var editorSelections: [UUID: NSRange] = [:]

    init(directory: URL) {
        settings = PreferencesStore(directory: directory)
        editorSession = EditorSessionStore(directory: directory)
        editorSelections = editorSession.positions.mapValues(\.selection)
        sidebarVisible = settings.preferences.sidebarAtLaunch
        let blank = Note()
        notebook = Notebook(repository: NoteRepository(directory: directory), initialNotes: [blank])
        sync = FolderSyncController(notebook: notebook, settings: settings)
        updates = UpdateController(settings: settings)
        loginItem = LoginItemController()
        backupStore = LibraryBackupStore(directory: directory.appendingPathComponent("backups"))
        if notebook.selectedNote == nil, notebook.canWrite {
            if let first = notebook.library.filtered(by: .all).first { notebook.select(first.id) }
        }
    }

    var visibleNotes: [Note] {
        let search = NoteSearchQuery(query)
        return notebook.library.filtered(by: filter, query: search.text, sort: settings.preferences.noteSort).filter(search.matches)
    }

    var editorSearchQuery: String { NoteSearchQuery(query).text }

    var currentFolderID: UUID? {
        if case .folder(let id) = filter, notebook.library.folders.contains(where: { $0.id == id }) { return id }
        return nil
    }

    var filterTitle: String {
        if let id = currentFolderID { return notebook.library.folderPath(id) }
        return filter.title
    }

    func openSettings() { onSettings?() }

    func showDataSettings() { settingsPane = .data; openSettings() }

    func checkForUpdates() {
        settingsPane = .about
        openSettings()
        Task { await updates.check() }
    }

    func startServices() { sync.start(); updates.start() }
    func stopServices() { sync.stop(); updates.stop(); editorSession.flush() }

    func renameTag(_ tag: String, to value: String) {
        guard let name = Note.normalizedTags([value]).first, name != tag, notebook.canWrite else { return }
        notebook.renameTag(tag, to: name)
        var icons = settings.preferences.tagIcons
        if let icon = icons.removeValue(forKey: tag), icons[name] == nil { icons[name] = icon }
        settings.preferences.tagIcons = icons
        if filter == .tag(tag) { changeFilter(.tag(name)) }
    }

    func removeTag(_ tag: String) {
        guard notebook.canWrite else { return }
        notebook.removeTag(tag)
        settings.preferences.tagIcons.removeValue(forKey: tag)
        if filter == .tag(tag) { changeFilter(.all) }
    }

    func editTitle() {
        guard notebook.selectedNote?.deletedAt == nil else { return }
        titleRequest = UUID()
    }

    func newNote() {
        guard notebook.canWrite else { return }
        searchRevealRequest = nil
        let tags: [String]
        if case .tag(let tag) = filter { tags = [tag] } else { tags = [] }
        let folderID = currentFolderID
        let starter = settings.preferences.newNoteStyle.starterText
        if let current = notebook.selectedNote, current.deletedAt == nil,
           current.isEmpty || (current.title.isEmpty && current.body == starter),
           current.tags == tags, current.folderID == folderID {
            if current.body.isEmpty, !starter.isEmpty {
                notebook.updateNote(current.id, body: starter)
            }
            editorSelections[current.id] = NSRange(location: (starter as NSString).length, length: 0)
            query = ""; focusBody()
            return
        }
        let note = notebook.createNote(tags: tags, folderID: folderID)
        if !starter.isEmpty {
            notebook.updateNote(note.id, body: starter)
            editorSelections[note.id] = NSRange(location: (starter as NSString).length, length: 0)
        }
        query = ""
        if filter == .trash || filter == .pinned { filter = .all }
        focusBody()
    }

    func select(_ note: Note) {
        notebook.select(note.id)
        searchRevealRequest = editorSearchQuery.isEmpty ? nil : UUID()
        focusBody()
    }

    func changeFilter(_ value: NoteFilter) {
        searchRevealRequest = nil
        filter = value
        let notes = visibleNotes
        if !notes.contains(where: { $0.id == notebook.selectedNote?.id }) { notebook.select(notes.first?.id) }
    }

    func toggleSidebar() {
        sidebarVisible.toggle()
        settings.preferences.sidebarAtLaunch = sidebarVisible
        onResize?(sidebarVisible)
    }

    func createFolder(parentID: UUID? = nil) {
        folderPrompt = FolderPrompt(folderID: nil, parentID: parentID, name: "")
    }

    func renameFolder(_ folder: NoteFolder) {
        folderPrompt = FolderPrompt(folderID: folder.id, parentID: folder.parentID, name: folder.name)
    }

    func saveFolder(_ prompt: FolderPrompt, name: String) {
        if let id = prompt.folderID {
            notebook.renameFolder(id, name: name)
        } else if let folder = notebook.createFolder(name: name, parentID: prompt.parentID) {
            query = ""
            changeFilter(.folder(folder.id))
        }
        folderPrompt = nil
    }

    func removeFolder(_ id: UUID) {
        let parent = notebook.library.folders.first { $0.id == id }?.parentID
        let removesCurrent = currentFolderID.map { notebook.library.descendantFolderIDs(id).contains($0) } ?? false
        notebook.removeFolder(id)
        if removesCurrent { changeFilter(parent.map(NoteFilter.folder) ?? .all) }
    }

    func moveNote(_ id: UUID, to folderID: UUID?) {
        notebook.moveNote(id, to: folderID)
        if !visibleNotes.contains(where: { $0.id == notebook.selectedNote?.id }) {
            notebook.select(visibleNotes.first?.id)
        }
    }

    func moveFolder(_ id: UUID, to parentID: UUID?) {
        notebook.moveFolder(id, to: parentID)
        if !visibleNotes.contains(where: { $0.id == notebook.selectedNote?.id }) {
            notebook.select(visibleNotes.first?.id)
        }
    }

    func search() {
        inputFocus = .search
        if !sidebarVisible { toggleSidebar() }
        searchRequest = UUID()
    }

    func focusBody() {
        inputFocus = .body
        focusRequest = UUID()
    }

    func trash(_ id: UUID) {
        notebook.moveToTrash(id)
        if !visibleNotes.contains(where: { $0.id == notebook.selectedNote?.id }) {
            notebook.select(visibleNotes.first?.id)
        }
        message("Moved to Trash")
        undoTrashID = id
    }

    func undoTrash() {
        guard let id = undoTrashID else { return }
        notebook.restore(id)
        filter = .all
        notebook.select(id)
        message("Note restored")
        focusBody()
    }

    func restore(_ id: UUID) {
        searchRevealRequest = nil
        notebook.restore(id)
        filter = .all
        message("Note restored")
    }

    func copyMarkdown() {
        guard let note = notebook.selectedNote else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(note.exportedMarkdown, forType: .string)
        message("Markdown copied")
    }

    func exportNote() {
        guard let note = notebook.selectedNote else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.nameFieldStringValue = note.displayTitle.replacingOccurrences(of: "/", with: "-") + ".md"
        panel.title = "Export Markdown"
        panel.prompt = "Export"
        guard let window = NSApp.keyWindow else { return }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try note.exportedMarkdown.write(to: url, atomically: true, encoding: .utf8)
                self?.message("Note exported")
            } catch { self?.operationError = error.localizedDescription }
        }
    }

    func revealStorage() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: notebook.directory.path)
    }

    func message(_ text: String) {
        undoTrashID = nil
        transientMessage = text
        messageTask?.cancel()
        messageTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            self?.transientMessage = nil
            self?.undoTrashID = nil
        }
    }
}
