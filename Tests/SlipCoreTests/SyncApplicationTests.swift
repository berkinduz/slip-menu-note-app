import Foundation
import Testing
@testable import SlipCore

@Suite("Applying synchronized notes", .serialized)
@MainActor
struct SyncApplicationTests {
    @Test("Confirmed restore preserves dirty in-memory edits even when the normal save fails")
    func restorePreservesDirtyMemory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = NoteRepository(directory: directory)
        let note = Note(body: "Old disk text")
        try repository.save(NoteLibrary(notes: [note]))
        let notebook = Notebook(repository: repository)
        notebook.updateNote(note.id, body: "Unsaved latest text")
        try Data("corrupt".utf8).write(to: repository.fileURL)
        notebook.flush()
        #expect(notebook.saveState == .failed)
        try notebook.restoreLibrary(NoteLibrary(notes: [Note(body: "Restored")]))
        let store = LibraryBackupStore(directory: directory.appendingPathComponent("backups"))
        #expect(try store.list().contains { try store.load($0.url).notes.contains { $0.body == "Unsaved latest text" } })
        #expect(notebook.canWrite)
        #expect(notebook.library.notes.first?.body == "Restored")
    }
    @Test("An incoming snapshot never overwrites typing that happened while sync was running")
    func rejectsStaleSnapshot() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let notebook = Notebook(repository: NoteRepository(directory: directory))
        let note = notebook.createNote()
        notebook.updateNote(note.id, body: "Before sync")
        notebook.flush()
        let snapshot = notebook.library
        var incoming = snapshot
        incoming.notes[0].body = "From the other Mac"
        notebook.updateNote(note.id, body: "Typed while syncing")
        #expect(try !notebook.applySynchronizedLibrary(incoming, basedOn: snapshot))
        #expect(notebook.selectedNote?.body == "Typed while syncing")
        notebook.flush()
        #expect(try NoteRepository(directory: directory).load()?.notes.first?.body == "Typed while syncing")
    }

    @Test("Applying remote notes preserves a newer local selection and makes a recoverable snapshot")
    func preservesSelectionAndBackup() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = Note(title: "One", body: "Original")
        let second = Note(title: "Two", body: "Keep selected")
        try NoteRepository(directory: directory).save(NoteLibrary(notes: [first, second], selectedNoteID: first.id))
        let notebook = Notebook(repository: NoteRepository(directory: directory))
        let snapshot = notebook.library
        var incoming = snapshot
        incoming.notes[0].body = "Remote edit"
        notebook.select(second.id)
        #expect(try notebook.applySynchronizedLibrary(incoming, basedOn: snapshot))
        #expect(notebook.selectedNote?.id == second.id)
        #expect(try NoteRepository(directory: directory).load()?.notes.first?.body == "Remote edit")
        let backups = LibraryBackupStore(directory: directory.appendingPathComponent("backups"))
        let original = try #require(backups.list().first)
        #expect(try backups.load(original.url).notes.first?.body == "Original")
    }
}
