import Foundation
import Testing
@testable import SlipCore

@Suite("Library transfer")
struct LibraryTransferTests {
    @Test("Archives retain IDs, nested folders, metadata, selection and Trash")
    func archiveRoundTrip() throws {
        let root = NoteFolder(name: "Work")
        let child = NoteFolder(name: "日本語", parentID: root.id)
        let date = Date(timeIntervalSince1970: 1_234.125)
        let note = Note(title: "İstanbul 📝", body: "**Markdown**\n- [ ] keep", tags: ["work/ideas"], folderID: child.id, isPinned: true, createdAt: date, updatedAt: date, deletedAt: date)
        let library = NoteLibrary(notes: [note], folders: [root, child], selectedNoteID: note.id)
        #expect(try LibraryTransfer.decodeArchive(LibraryTransfer.archive(library)) == library)
    }

    @Test("Malformed archives and future archive/library formats are rejected")
    func invalidArchives() throws {
        #expect(throws: (any Error).self) { try LibraryTransfer.decodeArchive(Data("{ broken".utf8)) }
        let library = NoteLibrary()
        let data = try LibraryTransfer.archive(library)
        var json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["version"] = 999
        #expect(throws: (any Error).self) { try LibraryTransfer.decodeArchive(JSONSerialization.data(withJSONObject: json)) }
        json["version"] = 1
        json["format"] = "another-app"
        #expect(throws: (any Error).self) { try LibraryTransfer.decodeArchive(JSONSerialization.data(withJSONObject: json)) }
        var future = library
        future.version = 999
        #expect(throws: (any Error).self) { try LibraryTransfer.archive(future) }
        json["format"] = "slip-backup"
        json["library"] = ["version": 999, "notes": [], "folders": []]
        #expect(throws: (any Error).self) { try LibraryTransfer.decodeArchive(JSONSerialization.data(withJSONObject: json)) }
    }

    @Test("Imported folder graphs cannot contain cycles or duplicate IDs")
    func invalidGraphs() throws {
        let aID = UUID(), bID = UUID()
        for folders in [
            [NoteFolder(id: aID, name: "Self", parentID: aID)],
            [NoteFolder(id: aID, name: "A", parentID: bID), NoteFolder(id: bID, name: "B", parentID: aID)],
            [NoteFolder(id: aID, name: "A"), NoteFolder(id: aID, name: "Duplicate")]
        ] {
            let library = NoteLibrary(folders: folders)
            #expect(throws: (any Error).self) { try LibraryTransfer.archive(library) }
            let json: [String: Any] = ["format": "slip-backup", "version": 1, "createdAt": 0,
                "library": try JSONSerialization.jsonObject(with: JSONEncoder().encode(library))]
            #expect(throws: (any Error).self) { try LibraryTransfer.decodeArchive(JSONSerialization.data(withJSONObject: json)) }
        }
        let note = Note(body: "Duplicate")
        #expect(throws: (any Error).self) { try LibraryTransfer.archive(NoteLibrary(notes: [note, note])) }
    }

    @Test("Archives preserve unresolved references from partial folder delivery")
    func unresolvedFolderReferences() throws {
        let pendingID = UUID()
        let child = NoteFolder(name: "Awaiting its parent", parentID: pendingID)
        let note = Note(body: "Awaiting its folder", folderID: pendingID)
        let library = NoteLibrary(notes: [note], folders: [child], selectedNoteID: note.id)
        #expect(try LibraryTransfer.decodeArchive(LibraryTransfer.archive(library)) == library)
        // Import cannot attach an unresolved foreign reference to a coincidentally matching local ID.
        let local = NoteLibrary(folders: [NoteFolder(id: pendingID, name: "Unrelated local folder")])
        let merged = LibraryTransfer.merging(library, into: local)
        #expect(merged.notes.first?.folderID == nil)
        #expect(merged.folders.last?.parentID == nil)
        #expect(merged.folders.first?.id == pendingID)
    }

    @Test("Import adds remapped copies even when every ID and title collides")
    func importCopies() throws {
        let root = NoteFolder(name: "Work")
        let child = NoteFolder(name: "Nested", parentID: root.id)
        let date = Date(timeIntervalSince1970: 100)
        let note = Note(title: "Same title", body: "Keep **exactly**", tags: ["work"], folderID: child.id, isPinned: true, createdAt: date, updatedAt: date, deletedAt: date)
        let library = NoteLibrary(notes: [note], folders: [root, child], selectedNoteID: note.id)
        let merged = LibraryTransfer.merging(library, into: library)
        try #require(merged.notes.count == 2)
        try #require(merged.folders.count == 4)
        #expect(merged.notes.first == note)
        #expect(merged.folders.prefix(2) == library.folders[...])
        #expect(merged.selectedNoteID == note.id)
        let imported = try #require(merged.notes.last)
        #expect(imported.id != note.id)
        #expect(imported.title == "Same title")
        #expect(imported.body == note.body && imported.tags == note.tags)
        #expect(imported.isPinned && imported.deletedAt == date && imported.createdAt == date && imported.updatedAt == date)
        let importedChild = try #require(merged.folders.last)
        #expect(imported.folderID == importedChild.id)
        #expect(importedChild.id != child.id)
        #expect(importedChild.parentID == merged.folders[2].id)
        #expect(merged.folders[2].id != root.id)
        let twice = LibraryTransfer.merging(library, into: merged)
        #expect(twice.notes.count == 3 && Set(twice.notes.map(\.id)).count == 3)
        #expect(twice.folders.count == 6 && Set(twice.folders.map(\.id)).count == 6)
    }

    @Test("Noncanonical H1 Markdown keeps its source without adding another title")
    func markdownImport() throws {
        let markdown = "# İstanbul 📝\r\n\r\n**日本語**\r\n- [ ] görev\r\n"
        let imported = try LibraryTransfer.markdownNote(data: Data(markdown.utf8), filename: "different.md")
        #expect(imported.title.isEmpty)
        #expect(imported.body == markdown)
        let untitled = try LibraryTransfer.markdownNote(data: Data("No heading\n\n```swift\n# code\n```".utf8), filename: "Meeting notes.markdown")
        #expect(untitled.title == "Meeting notes")
        #expect(untitled.body == "No heading\n\n```swift\n# code\n```")
        #expect(try LibraryTransfer.markdownNote(data: Data(), filename: "").title.isEmpty)
        #expect(throws: (any Error).self) { try LibraryTransfer.markdownNote(data: Data([0xff, 0xfe]), filename: "broken.md") }
    }

    @Test("Canonical Markdown export survives import and re-export without duplicate headings")
    func canonicalMarkdownRoundTrip() throws {
        let body = "**日本語**\n- [ ] görev\n"
        let source = "# İstanbul 📝\n\n**日本語**\n- [ ] görev\n"
        #expect(Note(title: "İstanbul 📝", body: body).exportedMarkdown == source)
        let imported = try LibraryTransfer.markdownNote(data: Data(source.utf8), filename: "different.md")
        #expect(imported.title == "İstanbul 📝")
        #expect(imported.body == body)
        #expect(imported.exportedMarkdown == source)
    }

    @Test("A leading H1 without a blank separator remains in the body exactly once")
    func headingWithoutSeparator() throws {
        let source = "# Keep this heading\nBody after heading\n\nAnother paragraph\n"
        let imported = try LibraryTransfer.markdownNote(data: Data(source.utf8), filename: "different.md")
        #expect(imported.title.isEmpty)
        #expect(imported.body == source)
        #expect(imported.exportedMarkdown == source)
    }
}
