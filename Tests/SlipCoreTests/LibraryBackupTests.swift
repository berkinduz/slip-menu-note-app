import Foundation
import Testing
@testable import SlipCore

@Suite("Library backup snapshots")
struct LibraryBackupTests {
    @Test("Snapshots are portable archives listed newest first")
    func portableSnapshots() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LibraryBackupStore(directory: directory)
        #expect(try store.list().isEmpty)
        let library = NoteLibrary(notes: [Note(body: "Original 📝", tags: ["keep"], isPinned: true)])
        let old = try store.create(library, now: Date(timeIntervalSince1970: 100))
        let newest = try store.create(NoteLibrary(), now: Date(timeIntervalSince1970: 200))
        let snapshots = try store.list()
        #expect(snapshots.map(\.url) == [newest, old])
        #expect(snapshots.map(\.createdAt) == [Date(timeIntervalSince1970: 200), Date(timeIntervalSince1970: 100)])
        #expect(try store.load(old) == library)
        #expect(try LibraryTransfer.decodeArchive(Data(contentsOf: old)) == library)
    }

    @Test("Retention keeps the newest thirty without overwriting snapshots sharing a timestamp")
    func boundedRetention() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LibraryBackupStore(directory: directory)
        for index in 0..<33 {
            _ = try store.create(NoteLibrary(notes: [Note(body: "Snapshot \(index)")]), now: Date(timeIntervalSince1970: Double(index)))
        }
        let snapshots = try store.list()
        #expect(snapshots.count == 30)
        #expect(try store.load(#require(snapshots.last).url).notes.first?.body == "Snapshot 3")
        let a = try store.create(NoteLibrary(), now: Date(timeIntervalSince1970: 100))
        let b = try store.create(NoteLibrary(), now: Date(timeIntervalSince1970: 100))
        #expect(a != b)
        #expect(FileManager.default.fileExists(atPath: a.path) && FileManager.default.fileExists(atPath: b.path))
        #expect(try store.list().count == 30)
    }

    @Test("Invalid data never replaces a valid snapshot")
    func invalidSnapshotPreservation() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LibraryBackupStore(directory: directory)
        let library = NoteLibrary(notes: [Note(body: "Keep")])
        let valid = try store.create(library)
        let original = try Data(contentsOf: valid)
        var unsupported = library
        unsupported.version = 999
        #expect(throws: (any Error).self) { try store.create(unsupported) }
        let corrupt = directory.appendingPathComponent("broken.slipbackup")
        try Data("{ broken".utf8).write(to: corrupt)
        #expect(throws: (any Error).self) { try store.load(corrupt) }
        #expect(try store.list().map(\.url) == [valid])
        #expect(try Data(contentsOf: valid) == original)
    }
}
