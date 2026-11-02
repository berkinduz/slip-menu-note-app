import Foundation

public struct NoteRepository: Sendable {
    public let directory: URL
    public var fileURL: URL { directory.appendingPathComponent("library.json") }

    public init(directory: URL) { self.directory = directory }

    public func load() throws -> NoteLibrary? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let decoder = JSONDecoder()
        let library = try decoder.decode(NoteLibrary.self, from: Data(contentsOf: fileURL))
        guard library.version == 1 || library.version == 2 else { throw RepositoryError.unsupportedVersion(library.version) }
        return library
    }

    public func save(_ library: NoteLibrary) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(library).write(to: fileURL, options: .atomic)
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
