import Foundation

public struct NoteRepository: Sendable {
    public let directory: URL
    public var fileURL: URL { directory.appendingPathComponent("library.json") }
    private let backupSchedule = LibraryBackupSchedule()

    public init(directory: URL) { self.directory = directory }

    public func load() throws -> NoteLibrary? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try decodedLibrary(Data(contentsOf: fileURL))
    }

    public func save(_ library: NoteLibrary) throws {
        try LibraryTransfer.validate(library)
        // Read before any write: recovery must never overwrite an invalid original.
        let previous = try load()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(library)
        if let previous {
            let backups = LibraryBackupStore(directory: directory.appendingPathComponent("backups"))
            let now = Date.now
            if try backupSchedule.needsSnapshot(in: backups, now: now) {
                try backups.create(previous, now: now)
            }
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }

    /// Explicit replacement preserves either a valid snapshot or the original unreadable bytes.
    public func restore(_ library: NoteLibrary) throws {
        try LibraryTransfer.validate(library)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(library)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let original = try Data(contentsOf: fileURL)
            let backups = LibraryBackupStore(directory: directory.appendingPathComponent("backups"))
            if let previous = try? decodedLibrary(original) {
                try backups.create(previous)
            } else {
                try FileManager.default.createDirectory(at: backups.directory, withIntermediateDirectories: true)
                let recoveryURL = backups.directory.appendingPathComponent("\(Date.now.timeIntervalSince1970)-\(UUID().uuidString).library-recovery.json")
                try original.write(to: recoveryURL, options: .atomic)
            }
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL, options: .atomic)
    }

    private func decodedLibrary(_ data: Data) throws -> NoteLibrary {
        let library = try JSONDecoder().decode(NoteLibrary.self, from: data)
        guard (1...3).contains(library.version) else { throw RepositoryError.unsupportedVersion(library.version) }
        try LibraryTransfer.validate(library)
        return library
    }

    public enum RepositoryError: LocalizedError {
        case unsupportedVersion(Int)
        public var errorDescription: String? {
            switch self {
            case .unsupportedVersion(let version): "This library uses an unsupported format (version \(version))."
            }
        }
    }
}
