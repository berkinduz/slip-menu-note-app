import Foundation

public struct TagSuggestion: Identifiable, Equatable, Sendable {
    public let name: String
    public let isNew: Bool
    public var id: String { name }
}

public extension NoteLibrary {
    /// Explicit labels only; legacy parent paths are still available for searching.
    var assignedTags: [String] {
        Set(notes.filter { $0.deletedAt == nil }.flatMap(\.allTags)).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    func tagSuggestions(for draft: String, excluding selected: [String]) -> [TagSuggestion] {
        let term = Note.normalizedTags([draft]).first ?? ""
        let excluded = Set(Note.normalizedTags(selected))
        let available = assignedTags
        var result = available.filter {
            !excluded.contains($0) && (term.isEmpty || $0.localizedStandardContains(term))
        }.sorted { a, b in
            if a.hasPrefix(term) != b.hasPrefix(term) { return a.hasPrefix(term) }
            return a.localizedStandardCompare(b) == .orderedAscending
        }.prefix(6).map { TagSuggestion(name: $0, isNew: false) }
        if !term.isEmpty, !available.contains(term), !excluded.contains(term) {
            result.append(TagSuggestion(name: term, isNew: true))
        }
        return result
    }
}
