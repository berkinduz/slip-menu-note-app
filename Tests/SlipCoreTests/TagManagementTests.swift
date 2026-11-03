import Foundation
import Testing
@testable import SlipCore

@Suite("Manual tag management")
@MainActor
struct TagManagementTests {
    @Test("Suggestions use assigned tags, exclude selections and offer explicit creation")
    func suggestions() {
        let library = NoteLibrary(notes: [
            Note(tags: ["work/ideas", "my work", "workflow", "selected"]),
            Note(tags: ["hidden"], deletedAt: .now)
        ])
        #expect(library.assignedTags == ["my work", "selected", "work/ideas", "workflow"])
        let matches = library.tagSuggestions(for: "wo", excluding: ["work/ideas"])
        #expect(matches.map(\.name) == ["workflow", "my work", "wo"])
        #expect(matches.map(\.isNew) == [false, false, true])
        #expect(library.tagSuggestions(for: "#WORKFLOW#", excluding: []).map(\.isNew) == [false])
        #expect(library.tagSuggestions(for: "selected", excluding: ["selected"]).isEmpty)
        #expect(library.tagSuggestions(for: "   ", excluding: []).allSatisfy { !$0.isNew })
    }

    @Test("Renaming merges tags without changing note text, identity, folder or dates")
    func renameAndPersist() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let date = Date(timeIntervalSince1970: 12345)
        let folder = NoteFolder(name: "Work")
        let first = Note(body: "#work stays literal", tags: ["work", "review", "work/ideas"], folderID: folder.id,
                         isPinned: true, createdAt: date, updatedAt: date)
        let trashed = Note(body: "Keep this too", tags: ["work"], createdAt: date, updatedAt: date, deletedAt: date)
        let other = Note(body: "No assigned tags", updatedAt: date)
        let repository = NoteRepository(directory: directory)
        try repository.save(NoteLibrary(notes: [first, trashed, other], folders: [folder], selectedNoteID: first.id))
        let notebook = Notebook(repository: repository)
        notebook.renameTag("work", to: " #Review# ")
        notebook.flush()
        let restored = try #require(try repository.load())
        var expectedFirst = first
        expectedFirst.tags = ["review", "work/ideas"]
        var expectedTrash = trashed
        expectedTrash.tags = ["review"]
        #expect(restored.notes == [expectedFirst, expectedTrash, other])
        #expect(restored.folders == [folder])
        #expect(restored.selectedNoteID == first.id)
    }

    @Test("Removing a tag keeps its notes and other tags, including nested labels")
    func removeTag() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = Note(body: "Keep #work in the body", tags: ["work", "work/ideas", "later"])
        let notebook = Notebook(repository: NoteRepository(directory: directory), initialNotes: [original])
        notebook.removeTag("work")
        notebook.flush()
        var expected = original
        expected.tags = ["work/ideas", "later"]
        #expect(notebook.library.notes == [expected])
        #expect(try NoteRepository(directory: directory).load()?.notes == [expected])
    }
}
