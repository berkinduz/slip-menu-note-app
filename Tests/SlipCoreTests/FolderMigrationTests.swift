import Foundation
import Testing
@testable import SlipCore

@Suite("Folder library migration")
@MainActor
struct FolderMigrationTests {
    @Test("Legacy libraries upgrade without inventing folders or changing note metadata")
    func upgradeLegacyLibraries() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = NoteRepository(directory: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for version in [1, 2] {
            let fixture = #"""
            {
                "version": \#(version),
                "notes": [
                    {
                        "id": "11111111-1111-1111-1111-111111111111",
                        "title": "Keep THIS Title",
                        "body": "Body #inbody #Work/Ideas",
                        "tags": ["manual", "work/ideas"],
                        "isPinned": true,
                        "createdAt": 1000,
                        "updatedAt": 2000
                    },
                    {
                        "id": "22222222-2222-2222-2222-222222222222",
                        "title": "Trashed Note",
                        "body": "Preserve #Archive",
                        "tags": ["saved"],
                        "isPinned": false,
                        "createdAt": 1500,
                        "updatedAt": 2500,
                        "deletedAt": 3000
                    }
                ],
                "selectedNoteID": "11111111-1111-1111-1111-111111111111"
            }
            """#
            try Data(fixture.utf8).write(to: repository.fileURL)
            #expect(try repository.load()?.version == version)

            let notebook = Notebook(repository: repository)
            let activeID = try #require(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
            let trashedID = try #require(UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
            let active = Note(
                id: activeID, title: "Keep THIS Title", body: "Body #inbody #Work/Ideas",
                tags: version == 1 ? ["manual", "work/ideas", "inbody"] : ["manual", "work/ideas"],
                isPinned: true, createdAt: Date(timeIntervalSinceReferenceDate: 1000),
                updatedAt: Date(timeIntervalSinceReferenceDate: 2000)
            )
            let trashed = Note(
                id: trashedID, title: "Trashed Note", body: "Preserve #Archive",
                tags: version == 1 ? ["saved", "archive"] : ["saved"],
                createdAt: Date(timeIntervalSinceReferenceDate: 1500),
                updatedAt: Date(timeIntervalSinceReferenceDate: 2500),
                deletedAt: Date(timeIntervalSinceReferenceDate: 3000)
            )
            #expect(notebook.canWrite)
            #expect(notebook.saveState == .saved)
            #expect(notebook.library.version == 3)
            #expect(notebook.library.folders.isEmpty)
            #expect(notebook.library.notes == [active, trashed])
            #expect(notebook.library.selectedNoteID == activeID)
            let saved = try #require(try repository.load())
            #expect(saved.version == 3)
            let json = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: repository.fileURL)) as? [String: Any])
            #expect((json["folders"] as? [Any])?.isEmpty == true)

            let reopened = Notebook(repository: repository)
            #expect(reopened.library.notes == [active, trashed])
            #expect(reopened.library.selectedNoteID == activeID)
        }
    }
}
