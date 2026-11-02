import Foundation

public struct NoteTag: Equatable, Sendable {
    public let name: String
    /// UTF-16 source range including the opening and optional closing #.
    public let range: NSRange
}

/// Parses legacy inline labels only for the version-one library migration.
public enum NoteTags {
    public static func parse(in source: String) -> [NoteTag] {
        let text = source as NSString
        let blocked = excludedRanges(in: source)
        let pattern = #"(?<![\p{L}\p{N}_/#\\])#([\p{L}\p{N}_-]+(?:/[\p{L}\p{N}_-]+)*(?:[ \t]+[\p{L}\p{N}_/-]+)*)#(?![\p{L}\p{N}_])|(?<![\p{L}\p{N}_/#\\])#([\p{L}\p{N}_-]+(?:/[\p{L}\p{N}_-]+)*)"#
        let regex = try! NSRegularExpression(pattern: pattern)
        return regex.matches(in: source, range: NSRange(location: 0, length: text.length)).compactMap { match in
            guard !blocked.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) else { return nil }
            let capture = match.range(at: match.range(at: 1).location != NSNotFound ? 1 : 2)
            return NoteTag(name: text.substring(with: capture).lowercased(), range: match.range)
        }
    }

    private static func excludedRanges(in source: String) -> [NSRange] {
        let text = source as NSString
        var result: [NSRange] = []
        var position = 0
        var fence: (Character, Int)?
        while position < text.length {
            let line = text.lineRange(for: NSRange(location: position, length: 0))
            let value = text.substring(with: line)
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            let marker = trimmed.first.flatMap { c -> (Character, Int)? in
                guard c == "`" || c == "~" else { return nil }
                let count = trimmed.prefix(while: { $0 == c }).count
                return count >= 3 ? (c, count) : nil
            }
            if let active = fence {
                result.append(line)
                if let marker, marker.0 == active.0, marker.1 >= active.1,
                   trimmed.dropFirst(marker.1).trimmingCharacters(in: .whitespaces).isEmpty { fence = nil }
            } else if let marker {
                fence = marker; result.append(line)
            } else {
                for pattern in [#"(?<!\\)(`+).*?(?:\1|$)"#, #"\]\([^\n)]*(?:\)|$)"#, #"\b(?:https?://|www\.)[^\s<>]+"#] {
                    let regex = try! NSRegularExpression(pattern: pattern)
                    for match in regex.matches(in: value, range: NSRange(location: 0, length: (value as NSString).length)) {
                        result.append(NSRange(location: line.location + match.range.location, length: match.range.length))
                    }
                }
            }
            position = NSMaxRange(line)
        }
        return result
    }
}

public struct TagNode: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let children: [TagNode]

    public static func tree(for tags: [String]) -> [TagNode] {
        let paths = Set(Note.normalizedTags(tags))
        func nodes(_ parent: String) -> [TagNode] {
            let prefix = parent.isEmpty ? "" : parent + "/"
            let segments = Set(paths.compactMap { path -> String? in
                guard path.hasPrefix(prefix) else { return nil }
                let rest = String(path.dropFirst(prefix.count))
                guard let component = rest.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true).first,
                      !rest.hasPrefix("/") else { return nil }
                return String(component)
            })
            return segments.sorted().map { segment in
                let full = prefix + segment
                return TagNode(id: full, name: segment, children: nodes(full))
            }
        }
        return nodes("")
    }
}
