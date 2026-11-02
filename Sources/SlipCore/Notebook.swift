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
    public func createNote(tags: [String] = []) -> Note {
        let note = Note(tags: tags)
        guard canWrite else { return note }
        library.notes.insert(note, at: 0)
        library.selectedNoteID = note.id
        scheduleSave()
        return note
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
