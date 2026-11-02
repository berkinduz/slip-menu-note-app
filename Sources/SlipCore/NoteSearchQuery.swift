import Foundation

public struct NoteSearchQuery: Equatable, Sendable {
    public let tags: [String]
    public let text: String

    public init(_ source: String) {
        var remaining = source.trimmingCharacters(in: .whitespacesAndNewlines)
        var terms: [String] = []
        let expression = try! NSRegularExpression(pattern: #"^#([\p{L}\p{N}_/-]+(?:[ \t]+[\p{L}\p{N}_/-]+)*)#(?=\s|$)|^#([\p{L}\p{N}_/-]+)"#)
        while let match = expression.firstMatch(in: remaining, range: NSRange(location: 0, length: (remaining as NSString).length)) {
            let value = remaining as NSString
            let capture = match.range(at: match.range(at: 1).location == NSNotFound ? 2 : 1)
            terms.append(value.substring(with: capture).lowercased())
            remaining = value.substring(from: NSMaxRange(match.range)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        tags = Note.normalizedTags(terms)
        text = remaining
    }

    public func matches(_ note: Note) -> Bool {
        tags.allSatisfy { term in note.allTags.contains { $0.localizedStandardContains(term) } }
    }
}
