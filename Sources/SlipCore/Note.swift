import Foundation

public struct Note: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var body: String
    public var tags: [String]
    public var isPinned: Bool
    public let createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(), title: String = "", body: String = "", tags: [String] = [],
        isPinned: Bool = false, createdAt: Date = .now, updatedAt: Date = .now,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.tags = Self.normalizedTags(tags)
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    public var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let firstLine = body.split(whereSeparator: \.isNewline).first {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }
        let fallback = Self.plainText(firstLine.map(String.init) ?? "")
        return fallback.isEmpty ? "new note" : String(fallback.prefix(90))
    }

    public var excerpt: String {
        let plain = Self.plainText(body)
        return plain.isEmpty ? "a little space for your next thought." : String(plain.prefix(160))
    }

    private static func plainText(_ markdown: String) -> String {
        markdown
            .replacingOccurrences(of: #"(?m)^\s{0,3}(#{1,6}\s+|>\s*|[-*+]\s+(\[[ xX]\]\s*)?|\d+[.)]\s+)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\[([^\]]+)\]\([^)]*\)"#, with: "$1", options: .regularExpression)
            .replacingOccurrences(of: #"[*_`~]"#, with: "", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    public var allTags: [String] { Self.normalizedTags(tags) }

    public var wordCount: Int { body.split(whereSeparator: \.isWhitespace).count }
    public var isEmpty: Bool { title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    public static func normalizedTags(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            let tag = value.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
                .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return !tag.isEmpty && seen.insert(tag).inserted ? tag : nil
        }
    }

    public var exportedMarkdown: String {
        let heading = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return (heading.isEmpty ? "" : "# \(heading)\n\n") + body + (body.hasSuffix("\n") ? "" : "\n")
    }
}

public enum NoteFilter: Hashable, Sendable {
    case all, pinned, tag(String), trash

    public var title: String {
        switch self {
        case .all: "all notes"
        case .pinned: "pinned"
        case .tag(let tag): tag
        case .trash: "trash"
        }
    }
}

public struct NoteLibrary: Codable, Equatable, Sendable {
    public var version: Int = 2
    public var notes: [Note]
    public var selectedNoteID: UUID?

    public init(notes: [Note] = [], selectedNoteID: UUID? = nil) {
        self.notes = notes
        self.selectedNoteID = selectedNoteID
    }

    public var tags: [String] {
        let active = notes.filter { $0.deletedAt == nil }.flatMap(\.allTags)
        var paths = Set<String>()
        for tag in active {
            var path = ""
            for component in tag.split(separator: "/") {
                path += (path.isEmpty ? "" : "/") + component
                paths.insert(path)
            }
        }
        return paths.sorted()
    }

    public var tagTree: [TagNode] { TagNode.tree(for: tags) }

    public func filtered(by filter: NoteFilter, query: String = "") -> [Note] {
        let search = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return notes.filter { note in
            let matchesFilter: Bool
            switch filter {
            case .all: matchesFilter = note.deletedAt == nil
            case .pinned: matchesFilter = note.deletedAt == nil && note.isPinned
            case .tag(let tag):
                let normalized = Note.normalizedTags([tag]).first ?? ""
                matchesFilter = note.deletedAt == nil && !normalized.isEmpty && note.allTags.contains { $0 == normalized || $0.hasPrefix(normalized + "/") }
            case .trash: matchesFilter = note.deletedAt != nil
            }
            return matchesFilter && (search.isEmpty || [note.title, note.body, note.allTags.joined(separator: " ")].contains { $0.localizedStandardContains(search) })
        }.sorted { a, b in
            if filter != .trash && a.isPinned != b.isPinned { return a.isPinned }
            let aDate = filter == .trash ? (a.deletedAt ?? a.updatedAt) : a.updatedAt
            let bDate = filter == .trash ? (b.deletedAt ?? b.updatedAt) : b.updatedAt
            if aDate != bDate { return aDate > bDate }
            return a.id.uuidString < b.id.uuidString
        }
    }

    public mutating func moveToTrash(_ id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].deletedAt = .now
        if selectedNoteID == id { selectedNoteID = filtered(by: .all).first?.id }
    }

    public mutating func restore(_ id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].deletedAt = nil
    }

    public mutating func emptyTrash() {
        notes.removeAll { $0.deletedAt != nil }
        if !notes.contains(where: { $0.id == selectedNoteID }) {
            selectedNoteID = filtered(by: .all).first?.id
        }
    }
}
