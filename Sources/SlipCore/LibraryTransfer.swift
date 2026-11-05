import Foundation

public enum LibraryTransfer {
    public static func archive(_ library: NoteLibrary) throws -> Data {
        try archive(library, createdAt: .now)
    }

    public static func decodeArchive(_ data: Data) throws -> NoteLibrary {
        try decodedArchive(data).library
    }

    /// Adds independent copies from a validated archive, retaining the local selection.
    public static func merging(_ incoming: NoteLibrary, into existing: NoteLibrary) -> NoteLibrary {
        var result = existing
        var folderIDs: [UUID: UUID] = [:]
        for folder in incoming.folders { folderIDs[folder.id] = UUID() }
        result.folders += incoming.folders.map { folder in
            NoteFolder(id: folderIDs[folder.id]!, name: folder.name, parentID: folder.parentID.flatMap { folderIDs[$0] })
        }
        result.notes += incoming.notes.map { note in
            var copy = Note(
                title: note.title, body: note.body, tags: note.tags,
                folderID: note.folderID.flatMap { folderIDs[$0] }, isPinned: note.isPinned,
                createdAt: note.createdAt, updatedAt: note.updatedAt, deletedAt: note.deletedAt
            )
            copy.tags = note.tags
            return copy
        }
        return result
    }

    /// Split Slip's exported header from its body; retain other leading H1s in the source.
    public static func markdownNote(data: Data, filename: String) throws -> Note {
        guard let body = String(data: data, encoding: .utf8) else { throw TransferError.invalidUTF8 }
        let firstLine = String(body.prefix { !$0.isNewline }).trimmingCharacters(in: .whitespaces)
        if firstLine.hasPrefix("# ") || firstLine.hasPrefix("#\t") {
            let title = String(firstLine.dropFirst()).trimmingCharacters(in: .whitespaces)
            let header = "# \(title)\n\n"
            if !title.isEmpty, body.hasPrefix(header) {
                return Note(title: title, body: String(body.dropFirst(header.count)))
            }
            return Note(body: body)
        }
        let title = ((filename as NSString).lastPathComponent as NSString).deletingPathExtension
        return Note(title: title, body: body)
    }

    static func archive(_ library: NoteLibrary, createdAt: Date) throws -> Data {
        try validate(library)
        let archive = LibraryArchive(format: "slip-backup", version: 1, createdAt: createdAt, library: library)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(archive)
    }

    static func decodedArchive(_ data: Data) throws -> LibraryArchive {
        let archive = try JSONDecoder().decode(LibraryArchive.self, from: data)
        guard archive.format == "slip-backup" else { throw TransferError.invalidArchive }
        guard archive.version == 1 else { throw TransferError.unsupportedArchiveVersion(archive.version) }
        try validate(archive.library)
        return archive
    }

    static func validate(_ library: NoteLibrary) throws {
        guard (1...3).contains(library.version) else { throw TransferError.unsupportedLibraryVersion(library.version) }
        guard Set(library.notes.map(\.id)).count == library.notes.count,
              Set(library.folders.map(\.id)).count == library.folders.count else { throw TransferError.duplicateIDs }
        let folders = Dictionary(uniqueKeysWithValues: library.folders.map { ($0.id, $0) })
        var checked = Set<UUID>()
        for folder in library.folders {
            var visited = Set<UUID>()
            var current: UUID? = folder.id
            // Folder sync may deliver a child before its parent record.
            while let id = current, let node = folders[id], !checked.contains(id) {
                guard visited.insert(id).inserted else { throw TransferError.invalidFolders }
                current = node.parentID
            }
            checked.formUnion(visited)
        }
    }

    public enum TransferError: LocalizedError {
        case invalidArchive, unsupportedArchiveVersion(Int), unsupportedLibraryVersion(Int)
        case duplicateIDs, invalidFolders, invalidUTF8

        public var errorDescription: String? {
            switch self {
            case .invalidArchive: "This file is not a Slip backup."
            case .unsupportedArchiveVersion(let version): "This backup uses an unsupported format (version \(version))."
            case .unsupportedLibraryVersion(let version): "This library uses an unsupported format (version \(version))."
            case .duplicateIDs: "This library contains duplicate note or folder IDs."
            case .invalidFolders: "This library contains an invalid folder relationship."
            case .invalidUTF8: "This Markdown file is not valid UTF-8 text."
            }
        }
    }
}

struct LibraryArchive: Codable, Sendable {
    let format: String
    let version: Int
    let createdAt: Date
    let library: NoteLibrary
}
