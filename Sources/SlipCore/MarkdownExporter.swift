import Foundation

public enum MarkdownExporter {
    public static func export(_ library: NoteLibrary, to parent: URL) throws -> URL {
        try LibraryTransfer.validate(library)
        let root = unusedURL(in: parent, name: "Slip Markdown", suffix: "")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        var directories: [UUID: URL] = [:]
        let folders = Dictionary(uniqueKeysWithValues: library.folders.map { ($0.id, $0) })
        func directory(for folder: NoteFolder) throws -> URL {
            if let existing = directories[folder.id] { return existing }
            let container: URL
            if let parentID = folder.parentID, let parentFolder = folders[parentID] {
                container = try directory(for: parentFolder)
            } else { container = root }
            let url = unusedURL(in: container, name: exportName(folder.name), suffix: "")
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
            directories[folder.id] = url
            return url
        }
        for note in library.notes where note.deletedAt == nil {
            let container: URL
            if let id = note.folderID, let folder = folders[id] {
                container = try directory(for: folder)
            } else { container = root }
            let url = unusedURL(in: container, name: exportName(note.displayTitle), suffix: "md")
            try note.exportedMarkdown.write(to: url, atomically: true, encoding: .utf8)
        }
        return root
    }

    private static func exportName(_ name: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:").union(.controlCharacters)
        let value = name.components(separatedBy: forbidden).joined(separator: "-").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value != ".", value != ".." else { return "Untitled" }
        var result = ""
        for character in value {
            let next = result + String(character)
            if next.utf8.count > 200 { break }
            result = next
        }
        return result.isEmpty ? "Untitled" : result
    }

    private static func unusedURL(in directory: URL, name: String, suffix: String) -> URL {
        var index = 1
        while true {
            let stem = name + (index == 1 ? "" : " (\(index))")
            let url = directory.appendingPathComponent(stem + (suffix.isEmpty ? "" : "." + suffix))
            if !FileManager.default.fileExists(atPath: url.path) { return url }
            index += 1
        }
    }
}
