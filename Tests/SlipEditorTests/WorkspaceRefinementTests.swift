import Foundation
import Testing
@testable import Slip
import SlipCore

@Suite("Quick capture preferences", .serialized)
@MainActor
struct WorkspaceRefinementTests {
    @Test("Checklist capture reuses an unused draft and preserves the selected folder")
    func checklistDraft() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let workspace = Workspace(directory: directory)
        let folder = try #require(workspace.notebook.createFolder(name: "Work"))
        workspace.changeFilter(.folder(folder.id))
        workspace.settings.preferences.newNoteStyle = .task
        workspace.newNote()
        let first = try #require(workspace.notebook.selectedNote)
        #expect(first.body == "- [ ] ")
        #expect(first.folderID == folder.id)
        workspace.editorSelections[first.id] = NSRange(location: 0, length: 0)
        workspace.newNote()
        #expect(workspace.notebook.selectedNote?.id == first.id)
        #expect(workspace.editorSelections[first.id] == NSRange(location: 6, length: 0))
        workspace.notebook.updateNote(first.id, body: "- [ ] Send update")
        workspace.newNote()
        #expect(workspace.notebook.selectedNote?.id != first.id)
        #expect(workspace.notebook.selectedNote?.body == "- [ ] ")
        workspace.notebook.flush()
    }

    @Test("Sorting respects pinned notes and the active folder")
    func noteSort() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let folder = NoteFolder(name: "Work")
        let early = Date(timeIntervalSince1970: 100), late = Date(timeIntervalSince1970: 200)
        let a = Note(title: "Alpha", folderID: folder.id, createdAt: late, updatedAt: early)
        let b = Note(title: "Bravo", folderID: folder.id, createdAt: early, updatedAt: late)
        let pinned = Note(title: "Zebra", folderID: folder.id, isPinned: true)
        let outside = Note(title: "Outside")
        try NoteRepository(directory: directory).save(NoteLibrary(notes: [a, b, pinned, outside], folders: [folder]))
        let workspace = Workspace(directory: directory)
        workspace.changeFilter(.folder(folder.id))
        workspace.settings.preferences.noteSort = .title
        #expect(workspace.visibleNotes.map(\.id) == [pinned.id, a.id, b.id])
        workspace.settings.preferences.noteSort = .updated
        #expect(workspace.visibleNotes.map(\.id) == [pinned.id, b.id, a.id])
        workspace.settings.preferences.noteSort = .created
        #expect(workspace.visibleNotes.map(\.id) == [pinned.id, a.id, b.id])
        workspace.notebook.flush()
    }
}
