import Foundation
import Testing
@testable import SlipCore

@Suite("Independent folders")
@MainActor
struct FolderTests {
    @Test("Nested folders and note membership survive a disk round trip")
    func persistence() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = NoteRepository(directory: directory)
        let root = NoteFolder(name: "Work")
        let child = NoteFolder(name: "Project Alpha", parentID: root.id)
        let note = Note(title: "Keep My Case", body: "# Heading\n\nİstanbul 📝", tags: ["manual"], folderID: child.id, isPinned: true)
        let library = NoteLibrary(notes: [note], folders: [root, child], selectedNoteID: note.id)

        try repository.save(library)
        let loaded = try #require(try repository.load())
        #expect(loaded == library)
        #expect(loaded.folderPath(child.id) == "Work/Project Alpha")
        #expect(loaded.filtered(by: .folder(root.id)).map(\.id) == [note.id])
    }

    @Test("Folder filters include descendants and remain independent from tags")
    func nestedFiltering() {
        let root = NoteFolder(name: "Work")
        let child = NoteFolder(name: "Project Alpha", parentID: root.id)
        let grandchild = NoteFolder(name: "Decisions", parentID: child.id)
        let sibling = NoteFolder(name: "Personal")
        let rootNote = Note(body: "Root", tags: ["personal"], folderID: root.id)
        let childNote = Note(body: "Needle in a child", folderID: child.id)
        let deepNote = Note(body: "A deeper Needle", folderID: grandchild.id, isPinned: true)
        let siblingNote = Note(body: "Needle elsewhere", tags: ["work/project alpha"], folderID: sibling.id)
        let unfiled = Note(body: "Needle unfiled", tags: ["work/project alpha"])
        let trashed = Note(body: "Needle in trash", folderID: grandchild.id, deletedAt: .now)
        let library = NoteLibrary(
            notes: [rootNote, childNote, deepNote, siblingNote, unfiled, trashed],
            folders: [root, child, grandchild, sibling]
        )

        #expect(library.folderPath(grandchild.id) == "Work/Project Alpha/Decisions")
        #expect(library.descendantFolderIDs(root.id) == Set([root.id, child.id, grandchild.id]))
        #expect(library.descendantFolderIDs(grandchild.id) == Set([grandchild.id]))
        #expect(Set(library.filtered(by: .folder(root.id)).map(\.id)) == Set([rootNote.id, childNote.id, deepNote.id]))
        #expect(Set(library.filtered(by: .folder(child.id)).map(\.id)) == Set([childNote.id, deepNote.id]))
        #expect(library.filtered(by: .folder(root.id), query: "Needle").map(\.id) == [deepNote.id, childNote.id])
        #expect(Set(library.filtered(by: .tag("work")).map(\.id)) == Set([siblingNote.id, unfiled.id]))
        #expect(library.filtered(by: .trash).map(\.id) == [trashed.id])
        #expect(NoteLibrary(notes: [unfiled]).folders.isEmpty)
    }

    @Test("Creating or editing tags never creates or changes a folder")
    func creationAndManualTags() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = NoteRepository(directory: directory)
        let notebook = Notebook(repository: repository)
        let unfiled = notebook.createNote(tags: ["work/ideas"])
        #expect(unfiled.folderID == nil)
        #expect(notebook.library.folders.isEmpty)

        let root = try #require(notebook.createFolder(name: "  Work  "))
        let child = try #require(notebook.createFolder(name: "Project Alpha", parentID: root.id))
        let note = notebook.createNote(tags: ["personal"], folderID: child.id)
        notebook.updateNote(note.id, body: "My Text #literal", tags: ["Other/Manual"])
        notebook.flush()

        let reopened = Notebook(repository: repository)
        #expect(reopened.library.folders == [root, child])
        #expect(root.name == "Work")
        #expect(reopened.library.folderPath(child.id) == "Work/Project Alpha")
        #expect(reopened.selectedNote?.id == note.id)
        #expect(reopened.selectedNote?.folderID == child.id)
        #expect(reopened.selectedNote?.tags == ["other/manual"])
        #expect(reopened.selectedNote?.body == "My Text #literal")
        #expect(reopened.library.notes.first { $0.id == unfiled.id }?.folderID == nil)
        #expect(reopened.library.filtered(by: .folder(root.id)).map(\.id) == [note.id])
        #expect(reopened.library.filtered(by: .tag("work")).map(\.id) == [unfiled.id])
    }

    @Test("Renaming folders and moving notes preserve note text and metadata")
    func renameAndMove() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = NoteRepository(directory: directory)
        let root = NoteFolder(name: "Work")
        let child = NoteFolder(name: "Ideas", parentID: root.id)
        let other = NoteFolder(name: "Personal")
        let date = Date(timeIntervalSince1970: 1_000)
        let note = Note(title: "Keep Title", body: "**Keep** My Text", tags: ["work/ideas"], folderID: child.id, isPinned: true, createdAt: date, updatedAt: date)
        try repository.save(NoteLibrary(notes: [note], folders: [root, child, other], selectedNoteID: note.id))
        let notebook = Notebook(repository: repository)

        notebook.renameFolder(root.id, name: "Research Notes")
        #expect(notebook.library.folderPath(child.id) == "Research Notes/Ideas")
        #expect(notebook.library.notes == [note])
        #expect(notebook.library.selectedNoteID == note.id)

        notebook.moveNote(note.id, to: other.id)
        var moved = note
        moved.folderID = other.id
        #expect(notebook.library.notes == [moved])
        #expect(notebook.library.filtered(by: .folder(root.id)).isEmpty)
        #expect(notebook.library.filtered(by: .folder(other.id)).map(\.id) == [note.id])
        #expect(notebook.library.filtered(by: .tag("work")).map(\.id) == [note.id])

        notebook.moveNote(note.id, to: nil)
        moved.folderID = nil
        notebook.flush()
        let reopened = Notebook(repository: repository)
        #expect(reopened.library.notes == [moved])
        #expect(reopened.library.selectedNoteID == note.id)
        #expect(reopened.library.folderPath(child.id) == "Research Notes/Ideas")
    }

    @Test("Removing a folder subtree moves live and trashed notes to its parent")
    func removeSubtree() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = NoteRepository(directory: directory)
        let root = NoteFolder(name: "Work")
        let removed = NoteFolder(name: "Project Alpha", parentID: root.id)
        let child = NoteFolder(name: "Ideas", parentID: removed.id)
        let grandchild = NoteFolder(name: "Decisions", parentID: child.id)
        let sibling = NoteFolder(name: "Other", parentID: root.id)
        let date = Date(timeIntervalSince1970: 1_000)
        let direct = Note(title: "Direct", body: "Keep direct", tags: ["project alpha"], folderID: removed.id, isPinned: true, createdAt: date, updatedAt: date)
        let nested = Note(title: "Nested", body: "Keep **nested**", tags: ["work/ideas"], folderID: child.id, createdAt: date, updatedAt: date)
        let trashed = Note(title: "Archived", body: "Keep trash", tags: ["archive"], folderID: grandchild.id, isPinned: true, createdAt: date, updatedAt: date, deletedAt: date)
        let untouched = Note(title: "Other", body: "Keep other", folderID: sibling.id, createdAt: date, updatedAt: date)
        try repository.save(NoteLibrary(notes: [direct, nested, trashed, untouched], folders: [root, removed, child, grandchild, sibling], selectedNoteID: nested.id))
        let notebook = Notebook(repository: repository)

        notebook.removeFolder(removed.id)
        var expectedDirect = direct
        expectedDirect.folderID = root.id
        var expectedNested = nested
        expectedNested.folderID = root.id
        var expectedTrash = trashed
        expectedTrash.folderID = root.id
        #expect(notebook.library.folders == [root, sibling])
        #expect(notebook.library.notes == [expectedDirect, expectedNested, expectedTrash, untouched])
        #expect(notebook.library.selectedNoteID == nested.id)
        notebook.flush()
        #expect(try repository.load() == notebook.library)

        notebook.removeFolder(root.id)
        expectedDirect.folderID = nil
        expectedNested.folderID = nil
        expectedTrash.folderID = nil
        var expectedOther = untouched
        expectedOther.folderID = nil
        #expect(notebook.library.folders.isEmpty)
        #expect(notebook.library.notes == [expectedDirect, expectedNested, expectedTrash, expectedOther])
        #expect(notebook.library.selectedNoteID == nested.id)
        notebook.flush()
        #expect(try repository.load() == notebook.library)
    }

    @Test("Empty folder names cannot create or erase a named folder")
    func emptyNames() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let notebook = Notebook(repository: NoteRepository(directory: directory))
        #expect(notebook.createFolder(name: " \n ") == nil)
        let folder = try #require(notebook.createFolder(name: "Personal Notes"))
        notebook.renameFolder(folder.id, name: " \n ")
        #expect(notebook.library.folders == [folder])
        notebook.flush()
    }

    @Test("Moving a folder preserves its subtree and every note's metadata")
    func moveSubtree() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = NoteRepository(directory: directory)
        let work = NoteFolder(name: "Work")
        let project = NoteFolder(name: "Project Alpha", parentID: work.id)
        let child = NoteFolder(name: "Decisions", parentID: project.id)
        let personal = NoteFolder(name: "Personal Notes")
        let date = Date(timeIntervalSince1970: 1_000)
        let note = Note(title: "Keep Title", body: "Keep **My Text**", tags: ["work/ideas"], folderID: child.id, isPinned: true, createdAt: date, updatedAt: date)
        let trashed = Note(title: "Archived", body: "Keep Trash", tags: ["manual"], folderID: project.id, createdAt: date, updatedAt: date, deletedAt: date)
        try repository.save(NoteLibrary(notes: [note, trashed], folders: [work, project, child, personal], selectedNoteID: note.id))
        let notebook = Notebook(repository: repository)

        notebook.moveFolder(project.id, to: personal.id)
        var movedProject = project
        movedProject.parentID = personal.id
        #expect(notebook.library.folders == [work, movedProject, child, personal])
        #expect(notebook.library.folderPath(child.id) == "Personal Notes/Project Alpha/Decisions")
        #expect(notebook.library.descendantFolderIDs(work.id) == Set([work.id]))
        #expect(notebook.library.descendantFolderIDs(personal.id) == Set([personal.id, project.id, child.id]))
        #expect(notebook.library.notes == [note, trashed])
        #expect(notebook.library.selectedNoteID == note.id)
        notebook.flush()
        #expect(try repository.load() == notebook.library)

        notebook.moveFolder(project.id, to: nil)
        movedProject.parentID = nil
        #expect(notebook.library.folders == [work, movedProject, child, personal])
        #expect(notebook.library.folderPath(child.id) == "Project Alpha/Decisions")
        #expect(notebook.library.notes == [note, trashed])
        #expect(notebook.library.selectedNoteID == note.id)
        notebook.flush()
        #expect(try repository.load() == notebook.library)
    }

    @Test("Folders cannot move into themselves or their descendants")
    func rejectFolderCycles() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = NoteRepository(directory: directory)
        let root = NoteFolder(name: "Work")
        let child = NoteFolder(name: "Project Alpha", parentID: root.id)
        let grandchild = NoteFolder(name: "Decisions", parentID: child.id)
        let original = NoteLibrary(folders: [root, child, grandchild])
        try repository.save(original)
        let notebook = Notebook(repository: repository)

        notebook.moveFolder(root.id, to: grandchild.id)
        #expect(notebook.library == original)
        notebook.moveFolder(child.id, to: child.id)
        #expect(notebook.library == original)
        notebook.flush()
        #expect(try repository.load() == original)
    }

    @Test("Creating and moving folders require an existing parent target")
    func knownFolderTargets() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let notebook = Notebook(repository: NoteRepository(directory: directory))
        let root = try #require(notebook.createFolder(name: "Work"))
        let unknown = UUID()
        #expect(notebook.createFolder(name: "Lost", parentID: unknown) == nil)
        notebook.moveFolder(root.id, to: unknown)
        notebook.moveFolder(unknown, to: root.id)
        #expect(notebook.library.folders == [root])
        notebook.flush()
    }
}
