import Foundation
import Testing
@testable import SlipCore

@Suite("Repository backups")
struct RepositoryBackupTests {
    @Test("Removing every snapshot invalidates the cached automatic backup schedule")
    func removedBackupInventory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = NoteRepository(directory: directory)
        let store = LibraryBackupStore(directory: directory.appendingPathComponent("backups"))
        try repository.save(NoteLibrary(notes: [Note(body: "First")]))
        try repository.save(NoteLibrary(notes: [Note(body: "Second")]))
        try repository.save(NoteLibrary(notes: [Note(body: "Latest before removal")]))
        for backup in try store.list() { try FileManager.default.removeItem(at: backup.url) }
        #expect(try store.list().isEmpty)
        try repository.save(NoteLibrary(notes: [Note(body: "After removal")]))
        let snapshots = try store.list()
        #expect(snapshots.count == 1)
        #expect(try store.load(#require(snapshots.first).url).notes.first?.body == "Latest before removal")
    }

    @Test("Replacing a snapshot with invalid bytes invalidates its verified backup time")
    func changedBackupInventory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = NoteRepository(directory: directory)
        let store = LibraryBackupStore(directory: directory.appendingPathComponent("backups"))
        try repository.save(NoteLibrary(notes: [Note(body: "First")]))
        try repository.save(NoteLibrary(notes: [Note(body: "Current valid disk contents")]))
        let previous = try #require(try store.list().first)
        try Data("{ no longer a valid backup".utf8).write(to: previous.url)
        try repository.save(NoteLibrary(notes: [Note(body: "Next edit")]))
        let snapshots = try store.list()
        #expect(snapshots.count == 1)
        #expect(snapshots.first?.url != previous.url)
        #expect(try store.load(#require(snapshots.first).url).notes.first?.body == "Current valid disk contents")
    }

    @Test("Partial folder delivery survives repository saves and prior-state backups")
    func pendingFolderDelivery() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = NoteRepository(directory: directory)
        let missingID = UUID()
        let child = NoteFolder(name: "Child arrived first", parentID: missingID)
        let partial = NoteLibrary(notes: [Note(body: "Note arrived first", folderID: missingID)], folders: [child])
        try repository.save(partial)
        #expect(try repository.load() == partial)
        var edited = partial
        edited.notes[0].body = "Local edit while awaiting folder delivery"
        try repository.save(edited)
        #expect(try repository.load() == edited)
        let store = LibraryBackupStore(directory: directory.appendingPathComponent("backups"))
        let backup = try #require(try store.list().first)
        #expect(try store.load(backup.url) == partial)
        edited.folders.append(NoteFolder(id: missingID, name: "Parent delivered later"))
        try repository.save(edited)
        #expect(try repository.load()?.folderPath(child.id) == "Parent delivered later/Child arrived first")
        #expect(try repository.load()?.notes.first?.folderID == missingID)
    }

    @Test("Overwriting a saved library first snapshots the prior contents")
    func priorContents() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = NoteRepository(directory: directory)
        try repository.save(NoteLibrary(notes: [Note(body: "Original")]))
        try repository.save(NoteLibrary(notes: [Note(body: "Edited")]))
        let backups = directory.appendingPathComponent("backups")
        #expect(FileManager.default.fileExists(atPath: backups.path))
        if FileManager.default.fileExists(atPath: backups.path) {
            #expect(try FileManager.default.contentsOfDirectory(at: backups, includingPropertiesForKeys: nil).count == 1)
        }
        #expect(try repository.load()?.notes.first?.body == "Edited")
    }

    @Test("Automatic snapshots use prior disk state and a persistent thirty-minute interval")
    func periodicSnapshots() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = NoteRepository(directory: directory)
        let store = LibraryBackupStore(directory: directory.appendingPathComponent("backups"))
        try repository.save(NoteLibrary(notes: [Note(body: "First save")]))
        #expect(try store.list().isEmpty)
        let old = try store.create(NoteLibrary(), now: Date.now.addingTimeInterval(-1_801))
        try repository.save(NoteLibrary(notes: [Note(body: "Second save")]))
        let snapshots = try store.list()
        #expect(snapshots.count == 2)
        #expect(try store.load(#require(snapshots.first).url).notes.first?.body == "First save")
        #expect(snapshots.last?.url == old)
        // A fresh repository value must respect the snapshot left on disk.
        try NoteRepository(directory: directory).save(NoteLibrary(notes: [Note(body: "Third save")]))
        #expect(try store.list().count == 2)
        #expect(try repository.load()?.notes.first?.body == "Third save")
    }

    @Test("A snapshot write failure leaves the prior library intact")
    func failedBackupPreservesPrior() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = NoteRepository(directory: directory)
        let original = NoteLibrary(notes: [Note(body: "Original")])
        try repository.save(original)
        try Data("A file blocks the backup directory".utf8).write(to: directory.appendingPathComponent("backups"))
        #expect(throws: (any Error).self) { try repository.save(NoteLibrary()) }
        #expect(try repository.load() == original)
    }

    @Test("Saving cannot overwrite an unreadable or unsupported current library")
    func preserveInvalidLibrary() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = NoteRepository(directory: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for input in ["{ broken", #"{"version":999,"notes":[]}"#] {
            let original = Data(input.utf8)
            try original.write(to: repository.fileURL)
            #expect(throws: (any Error).self) { try repository.save(NoteLibrary()) }
            #expect(try Data(contentsOf: repository.fileURL) == original)
            #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("backups").path))
        }
    }
}
