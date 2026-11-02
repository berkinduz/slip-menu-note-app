import Foundation
import Testing
@testable import SlipCore

@Suite("Local notebook")
struct LibraryTests {
    @Test("Notes survive a local disk round trip with Unicode and metadata")
    func persistence() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = NoteRepository(directory: folder)
        let note = Note(title: "İstanbul 📝", body: "# Thought\n\n**Keep this** — 日本語", tags: ["work"], isPinned: true)
        let library = NoteLibrary(notes: [note], selectedNoteID: note.id)
        try repository.save(library)
        let loaded = try #require(try repository.load())
        #expect(loaded.notes == [note])
        #expect(loaded.selectedNoteID == note.id)
    }

    @Test("A missing library is distinguishable from an unreadable one")
    func missingAndCorrupt() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = NoteRepository(directory: folder)
        #expect(try repository.load() == nil)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let corrupt = Data("{ broken library".utf8)
        try corrupt.write(to: repository.fileURL)
        #expect(throws: (any Error).self) { try repository.load() }
        #expect(try Data(contentsOf: repository.fileURL) == corrupt)
    }

    @Test("Unsupported versions are not treated as an empty library")
    func unsupportedVersion() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let repository = NoteRepository(directory: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data(#"{"version":999,"notes":[],"selectedNoteID":null}"#.utf8).write(to: repository.fileURL)
        #expect(throws: (any Error).self) { try repository.load() }
    }

    @Test("Tags normalize case, whitespace, leading hashes, and duplicates")
    func tags() {
        #expect(Note.normalizedTags([" #Ideas ", "ideas", " WORK", "", "#work", "日本語"]) == ["ideas", "work", "日本語"])
    }

    @Test("Search matches titles, note contents, and tags without case sensitivity")
    func search() {
        let title = Note(title: "Project Indigo", body: "", tags: [])
        let body = Note(title: "Meeting", body: "Try INDIGO next", tags: [])
        let tag = Note(title: "Design", body: "", tags: ["indigo"])
        let other = Note(title: "Shopping", body: "Apples", tags: [])
        let library = NoteLibrary(notes: [title, body, tag, other])
        #expect(Set(library.filtered(by: .all, query: "inDiGo").map(\.id)) == Set([title.id, body.id, tag.id]))
        #expect(library.filtered(by: .tag("indigo"), query: "").map(\.id) == [tag.id])
        #expect(library.filtered(by: .all, query: "  ").count == 4)
    }

    @Test("Pinned notes lead the library and trash is excluded from active filters")
    func orderAndTrash() {
        let old = Date(timeIntervalSince1970: 1_000)
        let recent = Date(timeIntervalSince1970: 2_000)
        let a = Note(title: "Recent", body: "", updatedAt: recent)
        let b = Note(title: "Pinned", body: "", isPinned: true, updatedAt: old)
        var c = Note(title: "Deleted", body: "", tags: ["only-in-trash"], isPinned: true)
        c.deletedAt = recent
        let library = NoteLibrary(notes: [a, b, c])
        #expect(library.filtered(by: .all).map(\.id) == [b.id, a.id])
        #expect(library.filtered(by: .pinned).map(\.id) == [b.id])
        #expect(library.filtered(by: .trash).map(\.id) == [c.id])
        #expect(library.tags.isEmpty)
    }

    @Test("Deleting and restoring retain a note's content, tags, and identity")
    func restore() {
        let note = Note(title: "Keep me", body: "A lasting thought", tags: ["ideas"])
        var library = NoteLibrary(notes: [note], selectedNoteID: note.id)
        library.moveToTrash(note.id)
        #expect(library.filtered(by: .all).isEmpty)
        #expect(library.filtered(by: .trash).first?.body == "A lasting thought")
        library.restore(note.id)
        #expect(library.filtered(by: .all).first?.id == note.id)
        #expect(library.filtered(by: .all).first?.tags == ["ideas"])
    }

    @Test("Permanent deletion only removes trashed notes")
    func emptyTrash() {
        let active = Note(title: "Keep", body: "")
        var deleted = Note(title: "Remove", body: "")
        deleted.deletedAt = .now
        var library = NoteLibrary(notes: [active, deleted], selectedNoteID: deleted.id)
        library.emptyTrash()
        #expect(library.notes.map(\.id) == [active.id])
        #expect(library.selectedNoteID == active.id)
    }
}
