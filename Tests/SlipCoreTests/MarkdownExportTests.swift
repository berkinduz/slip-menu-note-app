import Foundation
import Testing
@testable import SlipCore

@Suite("Portable Markdown export")
struct MarkdownExportTests {
    @Test("All active notes export without colliding filenames or leaving the chosen directory")
    func exportsFoldersAndDuplicateNames() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let folder = NoteFolder(name: "../Work")
        let duplicate = NoteFolder(name: "../Work")
        let first = Note(title: "Same/name", body: "First", folderID: folder.id)
        let second = Note(title: "Same/name", body: "Second", folderID: folder.id)
        let third = Note(title: String(repeating: "😀", count: 120), body: "Unicode", folderID: duplicate.id)
        let trashed = Note(title: "Trash", body: "Do not export", deletedAt: .now)
        let root = try MarkdownExporter.export(NoteLibrary(notes: [first, second, third, trashed], folders: [folder, duplicate]), to: directory)
        let files = try #require(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "md" }
        #expect(files.count == 3)
        #expect(Set(try files.map { try String(contentsOf: $0, encoding: .utf8) }) == [first.exportedMarkdown, second.exportedMarkdown, third.exportedMarkdown])
        for file in files {
            #expect(file.resolvingSymlinksInPath().path.hasPrefix(root.resolvingSymlinksInPath().path + "/"))
            #expect(file.lastPathComponent.utf8.count <= 255)
        }
        #expect(Set(files.map { $0.deletingLastPathComponent() }).count == 2)
    }
}
