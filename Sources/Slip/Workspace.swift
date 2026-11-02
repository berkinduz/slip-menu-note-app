import AppKit
import Observation
import SlipCore
import UniformTypeIdentifiers

enum InputFocus { case body, title, search }

@MainActor @Observable
final class Workspace {
    let notebook: Notebook
    let settings: PreferencesStore
    var query = ""
    var filter: NoteFilter = .all
    var sidebarVisible = false
    var keepOpen: Bool {
        get { settings.preferences.keepOpen }
        set { settings.preferences.keepOpen = newValue }
    }
    var showGuide = false
    var showTags = false
    var isEditingLink = false
    var confirmEmptyTrash = false
    var titleRequest = UUID()
    var focusRequest = UUID()
    var inputFocus: InputFocus = .body
    var searchRequest: UUID?
    var hotKeyAvailable = true
    var transientMessage: String?
    var operationError: String?
    @ObservationIgnored var onDismiss: (() -> Void)?
    @ObservationIgnored var onResize: ((Bool) -> Void)?
    @ObservationIgnored var onSettings: (() -> Void)?
    @ObservationIgnored private var messageTask: Task<Void, Never>?
    @ObservationIgnored var editorSelections: [UUID: NSRange] = [:]

    init(directory: URL) {
        settings = PreferencesStore(directory: directory)
        sidebarVisible = settings.preferences.sidebarAtLaunch
        let blank = Note()
        notebook = Notebook(repository: NoteRepository(directory: directory), initialNotes: [blank])
        if notebook.selectedNote == nil, notebook.canWrite {
            if let first = notebook.library.filtered(by: .all).first { notebook.select(first.id) }
        }
    }

    var visibleNotes: [Note] {
        let search = NoteSearchQuery(query)
        return notebook.library.filtered(by: filter, query: search.text).filter(search.matches)
    }

    func openSettings() { onSettings?() }

    func editTitle() {
        guard notebook.selectedNote?.deletedAt == nil else { return }
        titleRequest = UUID()
    }

    func newNote() {
        guard notebook.canWrite else { return }
        let tags: [String]
        if case .tag(let tag) = filter { tags = [tag] } else { tags = [] }
        if let current = notebook.selectedNote, current.isEmpty, current.deletedAt == nil, current.tags == tags {
            query = ""; focusBody()
            return
        }
        _ = notebook.createNote(tags: tags)
        query = ""
        if filter == .trash || filter == .pinned { filter = .all }
        focusBody()
    }

    func select(_ note: Note) {
        notebook.select(note.id)
        focusBody()
    }

    func changeFilter(_ value: NoteFilter) {
        filter = value
        let notes = visibleNotes
        if !notes.contains(where: { $0.id == notebook.selectedNote?.id }) { notebook.select(notes.first?.id) }
    }

    func toggleSidebar() {
        sidebarVisible.toggle()
        onResize?(sidebarVisible)
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
        if notebook.selectedNote == nil { notebook.select(visibleNotes.first?.id) }
        message("moved to trash")
    }

    func restore(_ id: UUID) {
        notebook.restore(id)
        filter = .all
        message("note restored")
    }

    func copyMarkdown() {
        guard let note = notebook.selectedNote else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(note.exportedMarkdown, forType: .string)
        message("markdown copied")
    }

    func exportNote() {
        guard let note = notebook.selectedNote else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        panel.nameFieldStringValue = note.displayTitle.replacingOccurrences(of: "/", with: "-") + ".md"
        panel.title = "export markdown"
        panel.prompt = "export"
        guard let window = NSApp.keyWindow else { return }
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try note.exportedMarkdown.write(to: url, atomically: true, encoding: .utf8)
                self?.message("note exported")
            } catch { self?.operationError = error.localizedDescription }
        }
    }

    func revealStorage() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: notebook.directory.path)
    }

    func message(_ text: String) {
        transientMessage = text
        messageTask?.cancel()
        messageTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            self?.transientMessage = nil
        }
    }
}
