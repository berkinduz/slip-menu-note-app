import Foundation
import Testing
@testable import SlipCore

@Suite("Explicit restore recovery backups")
struct RepositoryRestoreBackupTests {
    @Test("Explicit restore preserves corrupt and unsupported library bytes before recovery")
    func recoversUnreadableLibrary() throws {
        for bytes in [Data([0xff, 0x00, 0x7b]), Data(#"{"version":999,"notes":[]}"#.utf8)] {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: directory) }
            let repository = NoteRepository(directory: directory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try bytes.write(to: repository.fileURL)
            let restored = NoteLibrary(notes: [Note(body: "Recovered 📝")])
            #expect(throws: (any Error).self) { try repository.load() }
            try repository.restore(restored)
            #expect(try repository.load() == restored)
            let backupsDirectory = directory.appendingPathComponent("backups")
            let files = try FileManager.default.contentsOfDirectory(at: backupsDirectory, includingPropertiesForKeys: nil)
            let recovery = try #require(files.first)
            #expect(files.count == 1)
            #expect(try Data(contentsOf: recovery) == bytes)
            #expect(recovery.pathExtension != "slipbackup")
            #expect(try LibraryBackupStore(directory: backupsDirectory).list().isEmpty)
        }
    }

    @Test("Invalid restore input cannot alter the original or create a recovery file")
    func invalidIncomingPreservesOriginal() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = NoteRepository(directory: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let original = Data("{ damaged original".utf8)
        try original.write(to: repository.fileURL)
        var future = NoteLibrary()
        future.version = 999
        let cyclicID = UUID()
        let cyclic = NoteLibrary(folders: [NoteFolder(id: cyclicID, name: "Cycle", parentID: cyclicID)])
        for invalid in [future, cyclic] {
            #expect(throws: (any Error).self) { try repository.restore(invalid) }
            #expect(try Data(contentsOf: repository.fileURL) == original)
            #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("backups").path))
        }
    }

    @Test("Explicit restore always snapshots a valid current library even during the automatic interval")
    func validLibrarySnapshot() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = NoteRepository(directory: directory)
        let original = NoteLibrary(notes: [Note(body: "Previous valid library")])
        try repository.save(original)
        let store = LibraryBackupStore(directory: directory.appendingPathComponent("backups"))
        _ = try store.create(NoteLibrary())
        let replacement = NoteLibrary(notes: [Note(body: "Restored contents")])
        try repository.restore(replacement)
        #expect(try repository.load() == replacement)
        let backups = try store.list()
        #expect(backups.count == 2)
        #expect(try store.load(#require(backups.first).url) == original)
    }

    @Test("Failure preserving the original prevents restore from replacing it")
    func recoveryWriteFailure() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = NoteRepository(directory: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let original = Data("{ damaged original".utf8)
        try original.write(to: repository.fileURL)
        try Data("Blocked backup directory".utf8).write(to: directory.appendingPathComponent("backups"))
        #expect(throws: (any Error).self) { try repository.restore(NoteLibrary()) }
        #expect(try Data(contentsOf: repository.fileURL) == original)
    }
}
