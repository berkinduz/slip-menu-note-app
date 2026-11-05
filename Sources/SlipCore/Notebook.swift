import Foundation
import Observation

@MainActor @Observable
public final class Notebook {
    public private(set) var library = NoteLibrary()
    public private(set) var saveState: SaveState = .saved
    public private(set) var errorMessage: String?
    public private(set) var canWrite = false
    public let directory: URL

    @ObservationIgnored private let repository: NoteRepository
    @ObservationIgnored private var pendingSave: Task<Void, Never>?
    @ObservationIgnored private var isDirty = false

    public enum SaveState: Equatable, Sendable { case saved, saving, failed }

    public init(repository: NoteRepository, initialNotes: [Note] = []) {
        self.repository = repository
        directory = repository.directory
        do {
            if let existing = try repository.load() {
                library = existing
                if library.version == 1 {
                    for index in library.notes.indices {
                        let note = library.notes[index]
                        library.notes[index].tags = Note.normalizedTags(note.tags + NoteTags.parse(in: note.body).map(\.name))
                    }
                    library.version = 2
                    isDirty = true
                }
                if library.version == 2 {
                    library.version = 3
                    isDirty = true
                }
            } else {
                library = NoteLibrary(notes: initialNotes, selectedNoteID: initialNotes.first?.id)
                isDirty = true
            }
            canWrite = true
            flush()
        } catch {
            errorMessage = "Couldn’t open your notes. Your original library is unchanged. \(error.localizedDescription)"
            saveState = .failed
        }
    }

    public var selectedNote: Note? { library.notes.first { $0.id == library.selectedNoteID } }

    @discardableResult
    public func createNote(tags: [String] = [], folderID: UUID? = nil) -> Note {
        let note = Note(tags: tags, folderID: folderID)
        guard canWrite else { return note }
        library.notes.insert(note, at: 0)
        library.selectedNoteID = note.id
        scheduleSave()
        return note
    }

    @discardableResult
    public func createFolder(name: String, parentID: UUID? = nil) -> NoteFolder? {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canWrite, !name.isEmpty else { return nil }
        if let parentID, !library.folders.contains(where: { $0.id == parentID }) { return nil }
        let folder = NoteFolder(name: name, parentID: parentID)
        library.folders.append(folder)
        scheduleSave()
        return folder
    }

    public func renameFolder(_ id: UUID, name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canWrite, !name.isEmpty, let index = library.folders.firstIndex(where: { $0.id == id }) else { return }
        library.folders[index].name = name
        scheduleSave()
    }

    public func moveFolder(_ id: UUID, to parentID: UUID?) {
        guard canWrite, let index = library.folders.firstIndex(where: { $0.id == id }) else { return }
        if let parentID {
            guard library.folders.contains(where: { $0.id == parentID }),
                  !library.descendantFolderIDs(id).contains(parentID) else { return }
        }
        library.folders[index].parentID = parentID
        scheduleSave()
    }

    public func removeFolder(_ id: UUID) {
        guard canWrite, let folder = library.folders.first(where: { $0.id == id }) else { return }
        let removedIDs = library.descendantFolderIDs(id)
        library.folders.removeAll { removedIDs.contains($0.id) }
        for index in library.notes.indices {
            if let folderID = library.notes[index].folderID, removedIDs.contains(folderID) {
                library.notes[index].folderID = folder.parentID
            }
        }
        scheduleSave()
    }

    public func moveNote(_ id: UUID, to folderID: UUID?) {
        guard canWrite, let index = library.notes.firstIndex(where: { $0.id == id }) else { return }
        library.notes[index].folderID = folderID
        scheduleSave()
    }

    public func select(_ id: UUID?) {
        guard canWrite, library.selectedNoteID != id else { return }
        library.selectedNoteID = id
        scheduleSave()
    }

    public func updateNote(_ id: UUID, title: String? = nil, body: String? = nil, tags: [String]? = nil) {
        guard canWrite, let index = library.notes.firstIndex(where: { $0.id == id }), library.notes[index].deletedAt == nil else { return }
        if let title { library.notes[index].title = title }
        if let body { library.notes[index].body = body }
        if let tags { library.notes[index].tags = Note.normalizedTags(tags) }
        library.notes[index].updatedAt = .now
        scheduleSave()
    }

    public func togglePin(_ id: UUID) {
        guard canWrite, let index = library.notes.firstIndex(where: { $0.id == id }) else { return }
        library.notes[index].isPinned.toggle()
        scheduleSave()
    }

    public func renameTag(_ tag: String, to value: String) {
        guard canWrite, let name = Note.normalizedTags([value]).first, name != tag else { return }
        for index in library.notes.indices where library.notes[index].tags.contains(tag) {
            library.notes[index].tags = Note.normalizedTags(library.notes[index].tags.map { $0 == tag ? name : $0 })
        }
        scheduleSave()
    }

    public func removeTag(_ tag: String) {
        guard canWrite else { return }
        for index in library.notes.indices {
            library.notes[index].tags.removeAll { $0 == tag }
        }
        scheduleSave()
    }

    public func moveToTrash(_ id: UUID) {
        guard canWrite else { return }
        library.moveToTrash(id)
        scheduleSave()
    }

    public func restore(_ id: UUID) {
        guard canWrite else { return }
        library.restore(id)
        library.selectedNoteID = id
        scheduleSave()
    }

    public func emptyTrash() {
        guard canWrite else { return }
        library.emptyTrash()
        scheduleSave()
    }

    @discardableResult
    public func applySynchronizedLibrary(_ incoming: NoteLibrary, basedOn snapshot: NoteLibrary) throws -> Bool {
        guard library.notes == snapshot.notes, library.folders == snapshot.folders else { return false }
        if library.notes != incoming.notes || library.folders != incoming.folders {
            try replaceLibrary(incoming)
        }
        return true
    }

    public func replaceLibrary(_ incoming: NoteLibrary, preservingSelection: Bool = true) throws {
        guard canWrite else { throw CocoaError(.fileWriteNoPermission) }
        var replacement = incoming
        if preservingSelection { replacement.selectedNoteID = library.selectedNoteID }
        if !replacement.notes.contains(where: { $0.id == replacement.selectedNoteID }) {
            replacement.selectedNoteID = replacement.filtered(by: .all).first?.id
        }
        _ = try LibraryBackupStore(directory: directory.appendingPathComponent("backups")).create(library)
        try repository.save(replacement)
        pendingSave?.cancel()
        pendingSave = nil
        library = replacement
        isDirty = false
        errorMessage = nil
        saveState = .saved
    }

    public func restoreLibrary(_ incoming: NoteLibrary) throws {
        if canWrite {
            flush()
            if saveState == .failed {
                _ = try LibraryBackupStore(directory: directory.appendingPathComponent("backups")).create(library)
            }
        }
        try repository.restore(incoming)
        pendingSave?.cancel()
        pendingSave = nil
        library = incoming
        if !library.notes.contains(where: { $0.id == library.selectedNoteID }) {
            library.selectedNoteID = library.filtered(by: .all).first?.id
        }
        canWrite = true
        isDirty = false
        errorMessage = nil
        saveState = .saved
    }

    public func flush() {
        pendingSave?.cancel()
        pendingSave = nil
        guard canWrite, isDirty else { return }
        do {
            try repository.save(library)
            isDirty = false
            errorMessage = nil
            saveState = .saved
        } catch {
            errorMessage = "Your latest changes couldn’t be saved. \(error.localizedDescription)"
            saveState = .failed
        }
    }

    private func scheduleSave() {
        isDirty = true
        saveState = .saving
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            self?.flush()
        }
    }
}
