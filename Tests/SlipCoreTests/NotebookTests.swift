import Foundation
import Testing
@testable import SlipCore

@Suite("Capture autosave")
@MainActor
struct NotebookTests {
    @Test("Version-one inline labels migrate once without changing note content or identity")
    func migrateLegacyTagsOnce() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = NoteRepository(directory: folder)
        let date = Date(timeIntervalSince1970: 1_000)
        let note = Note(title: "Keep title", body: "😀 #Work/Ideas and #multi word# `#literal`", tags: ["Legacy", "work/ideas"], isPinned: true, createdAt: date, updatedAt: date)
        let trashed = Note(body: "#archived", deletedAt: date)
        var oldLibrary = NoteLibrary(notes: [note, trashed], selectedNoteID: note.id)
        oldLibrary.version = 1
        try repository.save(oldLibrary)

        let notebook = Notebook(repository: repository)
        #expect(notebook.canWrite)
        #expect(notebook.saveState == .saved)
        #expect(notebook.library.version == 3)
        var migrated = note
        migrated.tags = ["legacy", "work/ideas", "multi word"]
        var migratedTrash = trashed
        migratedTrash.tags = ["archived"]
        #expect(notebook.library.notes == [migrated, migratedTrash])
        #expect(notebook.library.selectedNoteID == note.id)
        #expect(try repository.load()?.version == 3)

        let reopened = Notebook(repository: repository)
        #expect(reopened.library.notes == [migrated, migratedTrash])
        reopened.updateNote(note.id, tags: ["legacy", "multi word"])
        reopened.flush()
        let afterRemoval = Notebook(repository: repository)
        #expect(afterRemoval.selectedNote?.tags == ["legacy", "multi word"])
        #expect(afterRemoval.selectedNote?.body == note.body)
        #expect(afterRemoval.library.filtered(by: .tag("work")).isEmpty)
    }

    @Test("New notes keep body hashtags literal across restarts")
    func manualTagsOnly() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = NoteRepository(directory: folder)
        let notebook = Notebook(repository: repository)
        let note = notebook.createNote()
        let body = "#literal #work/ideas #multi word#"
        notebook.updateNote(note.id, body: body)
        notebook.flush()
        let reopened = Notebook(repository: repository)
        #expect(reopened.library.version == 3)
        #expect(reopened.selectedNote?.body == body)
        #expect(reopened.selectedNote?.allTags == [])
        #expect(reopened.library.tags.isEmpty)
        #expect(reopened.library.tagTree.isEmpty)
        #expect(reopened.library.filtered(by: .tag("literal")).isEmpty)
        #expect(!NoteSearchQuery("#literal").matches(try #require(reopened.selectedNote)))

        reopened.updateNote(note.id, tags: ["Work/Ideas", "multi word"])
        reopened.flush()
        let manual = Notebook(repository: repository)
        #expect(manual.selectedNote?.allTags == ["work/ideas", "multi word"])
        #expect(manual.library.tags == ["multi word", "work", "work/ideas"])
        #expect(manual.library.filtered(by: .tag("work")).map(\.id) == [note.id])
        #expect(NoteSearchQuery("#work #multi word#").matches(try #require(manual.selectedNote)))
        #expect(manual.selectedNote?.body == body)
    }

    @Test("Unsupported library versions remain byte-for-byte unchanged")
    func preserveUnsupportedLibrary() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = NoteRepository(directory: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for version in [0, 99] {
            let bytes = Data("{\"version\":\(version),\"notes\":[],\"selectedNoteID\":null}".utf8)
            try bytes.write(to: repository.fileURL)
            let notebook = Notebook(repository: repository)
            #expect(!notebook.canWrite)
            #expect(notebook.saveState == .failed)
            _ = notebook.createNote(tags: ["work"])
            notebook.flush()
            #expect(try Data(contentsOf: repository.fileURL) == bytes)
        }
    }

    @Test("Closing immediately after typing persists the latest text and selection")
    func flushBeforeClose() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let notebook = Notebook(repository: NoteRepository(directory: folder))
        let note = notebook.createNote()
        notebook.updateNote(note.id, body: "First")
        notebook.updateNote(note.id, body: "Latest 📝")
        notebook.flush()
        let reopened = Notebook(repository: NoteRepository(directory: folder))
        #expect(reopened.selectedNote?.body == "Latest 📝")
        #expect(reopened.selectedNote?.id == note.id)
        #expect(reopened.saveState == .saved)
    }

    @Test("Typing is saved automatically without requiring dismissal")
    func autosave() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let notebook = Notebook(repository: NoteRepository(directory: folder))
        let note = notebook.createNote()
        notebook.updateNote(note.id, body: "Remember this")
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(3))
        while notebook.saveState == .saving, clock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(notebook.saveState == .saved)
        #expect(try NoteRepository(directory: folder).load()?.notes.first?.body == "Remember this")
    }

    @Test("An unreadable library cannot be replaced by an empty autosave")
    func preserveUnreadableLibrary() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let repository = NoteRepository(directory: folder)
        let bytes = Data("broken original".utf8)
        try bytes.write(to: repository.fileURL)
        let notebook = Notebook(repository: repository)
        #expect(!notebook.canWrite)
        #expect(notebook.errorMessage != nil)
        _ = notebook.createNote()
        #expect(notebook.createFolder(name: "Work") == nil)
        notebook.flush()
        #expect(try Data(contentsOf: repository.fileURL) == bytes)
    }
}
