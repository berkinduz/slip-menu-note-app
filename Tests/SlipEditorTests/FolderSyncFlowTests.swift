import Foundation
import Testing
import SlipCore
@testable import Slip

@Suite("Folder sync application flow", .serialized)
@MainActor
struct FolderSyncFlowTests {
    @Test("A failed local save is never published as an acknowledged sync revision")
    func failedLocalSave() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let shared = root.appendingPathComponent("shared")
        try FileManager.default.createDirectory(at: shared, withIntermediateDirectories: true)
        let repository = NoteRepository(directory: root.appendingPathComponent("local"))
        let note = Note(body: "On disk")
        try repository.save(NoteLibrary(notes: [note]))
        let notebook = Notebook(repository: repository)
        let settings = PreferencesStore(directory: repository.directory)
        settings.preferences.syncFolderBookmark = try shared.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        let sync = FolderSyncController(notebook: notebook, settings: settings)
        try Data("unreadable original".utf8).write(to: repository.fileURL)
        notebook.updateNote(note.id, body: "Unsaved new text")
        await sync.synchronize()
        #expect(notebook.saveState == .failed)
        #expect(sync.lastCheckedAt == nil)
        #expect(sync.errorMessage != nil)
        #expect(!FileManager.default.fileExists(atPath: shared.appendingPathComponent("Slip Sync/Records").path))
        #expect(notebook.library.notes.first?.body == "Unsaved new text")
    }

    @Test("Choosing a different folder merges live local notes without replaying old tombstones")
    func separateFolderHistories() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = root.appendingPathComponent("first"), second = root.appendingPathComponent("second")
        try FileManager.default.createDirectory(at: first, withIntermediateDirectories: true)
        let repository = NoteRepository(directory: root.appendingPathComponent("local"))
        let note = Note(body: "Keep the destination copy")
        try repository.save(NoteLibrary(notes: [note]))
        let notebook = Notebook(repository: repository)
        let settings = PreferencesStore(directory: repository.directory)
        settings.preferences.syncFolderBookmark = try first.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        let old = FolderSyncController(notebook: notebook, settings: settings)
        await old.synchronize()
        try FileManager.default.copyItem(at: first, to: second)
        notebook.moveToTrash(note.id)
        notebook.emptyTrash()
        await old.synchronize()
        settings.preferences.syncFolderBookmark = try second.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        let changed = FolderSyncController(notebook: notebook, settings: settings)
        await changed.synchronize()
        #expect(changed.errorMessage == nil)
        #expect(notebook.library.notes.first?.body == "Keep the destination copy")
    }

    @Test("Two application controllers exchange edits through a folder and persist them locally")
    func controllerRoundTrip() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let shared = root.appendingPathComponent("shared")
        try FileManager.default.createDirectory(at: shared, withIntermediateDirectories: true)
        let bookmark = try shared.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        let aURL = root.appendingPathComponent("a"), bURL = root.appendingPathComponent("b")
        let a = Notebook(repository: NoteRepository(directory: aURL))
        let b = Notebook(repository: NoteRepository(directory: bURL))
        let aPreferences = PreferencesStore(directory: aURL), bPreferences = PreferencesStore(directory: bURL)
        aPreferences.preferences.syncFolderBookmark = bookmark
        bPreferences.preferences.syncFolderBookmark = bookmark
        let left = FolderSyncController(notebook: a, settings: aPreferences)
        let right = FolderSyncController(notebook: b, settings: bPreferences)
        let note = a.createNote()
        a.updateNote(note.id, body: "From the first Mac")
        await left.synchronize()
        await right.synchronize()
        #expect(right.errorMessage == nil)
        #expect(b.library.notes.first?.body == "From the first Mac")
        b.updateNote(note.id, body: "Edited on the second Mac")
        await right.synchronize()
        await left.synchronize()
        #expect(left.errorMessage == nil)
        #expect(a.library.notes.first?.body == "Edited on the second Mac")
        #expect(try NoteRepository(directory: aURL).load()?.notes.first?.body == "Edited on the second Mac")
        #expect(left.lastCheckedAt != nil)
        left.disable()
        #expect(a.library.notes.first?.body == "Edited on the second Mac")
        #expect(aPreferences.preferences.syncFolderBookmark == nil)
    }
}
