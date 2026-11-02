import Foundation

/// A UTF-16 projection of Markdown; ranges always refer to the unchanged source.
public struct MarkdownPresentation: Sendable {
    public let source: String
    public enum Style: Equatable, Sendable {
        case strong, emphasis, strikethrough, highlight, code, link(destination: String)
        case heading(level: Int), quote, fence, rule
    }
    public struct Span: Equatable, Sendable {
        public let range: NSRange
        public let style: Style
    }
    public struct Replacement: Equatable, Sendable {
        public let range: NSRange
        public let text: String
        public let taskChecked: Bool?
    }
    public private(set) var hiddenRanges: [NSRange] = []
    public private(set) var spans: [Span] = []
    public private(set) var replacements: [Replacement] = []

    public init(source: String) {
        self.source = source
        let text = source as NSString
        var fence: (character: Character, length: Int, opening: NSRange)?
        var position = 0
        while position < text.length {
            let line = text.lineRange(for: NSRange(location: position, length: 0))
            let raw = text.substring(with: line) as NSString
            let content = raw.trimmingCharacters(in: .newlines)
            let length = (content as NSString).length
            let full = NSRange(location: line.location, length: length)
            let trimmed = content.trimmingCharacters(in: .whitespaces)
            let marker = trimmed.first.flatMap { character -> (Character, Int)? in
                guard character == "`" || character == "~" else { return nil }
                let count = trimmed.prefix(while: { $0 == character }).count
                return count >= 3 ? (character, count) : nil
            }
            if let active = fence {
                if let marker, marker.0 == active.character, marker.1 >= active.length,
                   trimmed.dropFirst(marker.1).trimmingCharacters(in: .whitespaces).isEmpty {
                    hiddenRanges.append(active.opening)
                    hiddenRanges.append(line)
                    fence = nil
                    spans.append(Span(range: full, style: .fence))
                } else {
                    spans.append(Span(range: full, style: .code))
                }
            } else if let marker {
                fence = (marker.0, marker.1, line)
                spans.append(Span(range: full, style: .fence))
            } else {
                parseLine(text, range: full)
            }
            position = NSMaxRange(line)
        }
        hiddenRanges.sort { $0.location < $1.location }
    }

    private mutating func parseLine(_ text: NSString, range: NSRange) {
        let line = text.substring(with: range)
        func matches(_ pattern: String) -> [NSTextCheckingResult] {
            let regex = try! NSRegularExpression(pattern: pattern)
            return regex.matches(in: line, range: NSRange(location: 0, length: (line as NSString).length))
        }
        func global(_ range: NSRange) -> NSRange { NSRange(location: range.location + rangeOffset, length: range.length) }
        let rangeOffset = range.location
        if !matches(#"^ {0,3}(?:\*[ \t]*){3,}$|^ {0,3}(?:-[ \t]*){3,}$|^ {0,3}(?:_[ \t]*){3,}$"#).isEmpty {
            hiddenRanges.append(range)
            spans.append(Span(range: range, style: .rule))
            return
        }
        if let m = matches(#"^( {0,3})(#{1,6})[ \t]+"#).first {
            hiddenRanges.append(global(m.range))
            spans.append(Span(range: NSRange(location: range.location + NSMaxRange(m.range), length: range.length - NSMaxRange(m.range)), style: .heading(level: m.range(at: 2).length)))
        } else if let m = matches(#"^ {0,3}>[ \t]?"#).first {
            hiddenRanges.append(global(m.range))
            spans.append(Span(range: NSRange(location: range.location + NSMaxRange(m.range), length: range.length - NSMaxRange(m.range)), style: .quote))
        } else if let m = matches(#"^(\s*)[-*+]\s+\[([ xX])\](?=\s|$)"#).first {
            let marker = NSRange(location: m.range(at: 1).length, length: NSMaxRange(m.range) - m.range(at: 1).length)
            let checked = (line as NSString).substring(with: m.range(at: 2)).lowercased() == "x"
            replacements.append(Replacement(range: global(marker), text: checked ? "☑" : "☐", taskChecked: checked))
        } else if let m = matches(#"^(\s*)[-*+](?=\s)"#).first {
            let marker = NSRange(location: m.range(at: 1).length, length: 1)
            replacements.append(Replacement(range: global(marker), text: "•", taskChecked: nil))
        }
        var protected: [NSRange] = []
        for m in matches(#"(?<!\\)(`+)(.+?)\1"#) {
            let whole = global(m.range); let content = global(m.range(at: 2))
            hiddenRanges += [NSRange(location: whole.location, length: m.range(at: 1).length), NSRange(location: NSMaxRange(content), length: m.range(at: 1).length)]
            spans.append(Span(range: content, style: .code)); protected.append(whole)
        }
        for m in matches(#"(?<!\\)\[([^\]\n]+)\]\(([^)\n]+)\)"#) {
            let whole = global(m.range); if protected.contains(where: { NSIntersectionRange($0, whole).length > 0 }) { continue }
            let label = global(m.range(at: 1)); let destination = (line as NSString).substring(with: m.range(at: 2))
            hiddenRanges += [NSRange(location: whole.location, length: 1), NSRange(location: NSMaxRange(label), length: NSMaxRange(whole) - NSMaxRange(label))]
            spans.append(Span(range: label, style: .link(destination: destination)))
            protected.append(NSRange(location: NSMaxRange(label), length: NSMaxRange(whole) - NSMaxRange(label)))
        }
        for pattern in [#"(?<![\\*])\*\*\*(?!\*)(?=\S)(.+?)(?<=\S)\*\*\*(?!\*)"#,
                        #"(?<![\\_\w])___(?!_)(?=\S)(.+?)(?<=\S)___(?![\w_])"#] {
            for m in matches(pattern) {
                let whole = global(m.range); let body = global(m.range(at: 1))
                if protected.contains(where: { NSLocationInRange(whole.location, $0) || NSLocationInRange(NSMaxRange(whole) - 1, $0) }) { continue }
                let opening = NSRange(location: whole.location, length: body.location - whole.location)
                let closing = NSRange(location: NSMaxRange(body), length: NSMaxRange(whole) - NSMaxRange(body))
                hiddenRanges += [opening, closing]
                protected += [opening, closing]
                spans += [Span(range: body, style: .strong), Span(range: body, style: .emphasis)]
            }
        }
        let patterns: [(String, Style)] = [
            (#"(?<![\\=])==(?!=)(?=\S)(.+?)(?<=\S)(?<!\\)==(?!=)"#, .highlight),
            (#"(?<![\\*])\*\*(?!\*)(?=\S)(.+?)(?<=\S)\*\*(?!\*)"#, .strong),
            (#"(?<![\\_\w])__(?!_)(?=\S)(.+?)(?<=\S)__(?![\w_])"#, .strong),
            (#"(?<![\\~])~~(?=\S)(.+?)(?<=\S)~~(?!~)"#, .strikethrough),
            (#"(?<![\\_\w])_(?!_)(?=\S)(.+?)(?<=\S)_(?![\w_])"#, .emphasis),
            (#"(?<![\\*])\*(?!\*)(?=\S)(.+?)(?<=\S)\*(?!\*)"#, .emphasis)
        ]
        for (pattern, style) in patterns {
            for m in matches(pattern) {
                let whole = global(m.range); let body = global(m.range(at: 1))
                if protected.contains(where: { NSLocationInRange(whole.location, $0) || NSLocationInRange(NSMaxRange(whole) - 1, $0) }) { continue }
                hiddenRanges += [NSRange(location: whole.location, length: body.location - whole.location), NSRange(location: NSMaxRange(body), length: NSMaxRange(whole) - NSMaxRange(body))]
                spans.append(Span(range: body, style: style))
            }
        }
    }

    public func visibleText(in source: String, range: NSRange) -> String {
        let text = source as NSString
        let safe = NSIntersectionRange(range, NSRange(location: 0, length: text.length))
        var result = ""
        var index = safe.location
        while index < NSMaxRange(safe) {
            if let replacement = replacements.first(where: { $0.range.location == index && NSMaxRange($0.range) <= NSMaxRange(safe) }) {
                result += replacement.text; index = NSMaxRange(replacement.range)
            } else if let hidden = hiddenRanges.first(where: { NSLocationInRange(index, $0) }) {
                index = min(NSMaxRange(hidden), NSMaxRange(safe))
            } else {
                let composed = text.rangeOfComposedCharacterSequence(at: index)
                let end = min(NSMaxRange(composed), NSMaxRange(safe))
                result += text.substring(with: NSRange(location: index, length: end - index)); index = end
            }
        }
        return result
    }

    public func adjustedSelection(from old: NSRange, to proposed: NSRange) -> NSRange {
        guard proposed.length == 0 else { return proposed }
        for range in hiddenRanges where proposed.location > range.location && proposed.location < NSMaxRange(range) {
            return NSRange(location: proposed.location >= old.location ? NSMaxRange(range) : range.location, length: 0)
        }
        return proposed
    }

    /// Move one displayed character, skipping concealed markup on the way.
    public func movingCaret(in source: String, from: Int, direction: Int) -> Int {
        let text = source as NSString
        var cursor = min(max(0, from), text.length)
        guard direction != 0 else { return cursor }
        if direction > 0 {
            while cursor < text.length {
                if let hidden = hiddenRanges.first(where: { NSLocationInRange(cursor, $0) }) {
                    cursor = NSMaxRange(hidden); continue
                }
                if let replacement = replacements.first(where: { NSLocationInRange(cursor, $0.range) }) {
                    return NSMaxRange(replacement.range)
                }
                return NSMaxRange(text.rangeOfComposedCharacterSequence(at: cursor))
            }
        } else {
            while cursor > 0 {
                if let hidden = hiddenRanges.first(where: { NSLocationInRange(cursor - 1, $0) }) {
                    cursor = hidden.location; continue
                }
                if let replacement = replacements.first(where: { NSLocationInRange(cursor - 1, $0.range) }) {
                    return replacement.range.location
                }
                return text.rangeOfComposedCharacterSequence(at: cursor - 1).location
            }
        }
        return cursor
    }

    public func backwardDeletion(in source: String, selection: NSRange) -> MarkdownEdit? {
        guard NSMaxRange(selection) <= (source as NSString).length else { return nil }
        if selection.length > 0 { return deletionOfWholeFormattedSpan(selection) }
        let text = source as NSString
        if let rule = spans.first(where: { $0.style == .rule && NSMaxRange($0.range) == selection.location }) {
            return MarkdownEdit(range: rule.range, replacement: "", selection: NSRange(location: rule.range.location, length: 0))
        }
        if let replacement = replacements.first(where: { NSMaxRange($0.range) == selection.location }) {
            return deletionOfReplacement(replacement, in: text)
        }
        if let block = spans.first(where: { span in
            guard span.range.location == selection.location else { return false }
            switch span.style { case .heading, .quote: return true; default: return false }
        }), let prefix = hiddenRanges.first(where: { NSMaxRange($0) == block.range.location }) {
            return MarkdownEdit(range: prefix, replacement: "", selection: NSRange(location: prefix.location, length: 0))
        }
        var cursor = selection.location
        while let marker = hiddenRanges.first(where: { NSMaxRange($0) == cursor }) { cursor = marker.location }
        guard cursor > 0 else { return nil }
        let character = text.rangeOfComposedCharacterSequence(at: cursor - 1)
        guard !hiddenRanges.contains(where: { NSIntersectionRange($0, character).length > 0 }) else { return nil }
        if let deletion = deletionOfWholeFormattedSpan(character) { return deletion }
        guard cursor != selection.location else { return nil }
        return MarkdownEdit(range: character, replacement: "", selection: NSRange(location: character.location, length: 0))
    }

    public func forwardDeletion(in source: String, selection: NSRange) -> MarkdownEdit? {
        let text = source as NSString
        guard NSMaxRange(selection) <= text.length else { return nil }
        if selection.length > 0 { return deletionOfWholeFormattedSpan(selection) }
        if let rule = spans.first(where: { $0.style == .rule && $0.range.location == selection.location }) {
            return MarkdownEdit(range: rule.range, replacement: "", selection: NSRange(location: rule.range.location, length: 0))
        }
        if let replacement = replacements.first(where: { $0.range.location == selection.location }) {
            return deletionOfReplacement(replacement, in: text)
        }
        var cursor = selection.location
        while let marker = hiddenRanges.first(where: { $0.location == cursor }) {
            cursor = NSMaxRange(marker)
        }
        guard cursor < text.length else { return nil }
        let character = text.rangeOfComposedCharacterSequence(at: cursor)
        guard !hiddenRanges.contains(where: { NSIntersectionRange($0, character).length > 0 }) else { return nil }
        if let deletion = deletionOfWholeFormattedSpan(character) { return deletion }
        guard cursor != selection.location else { return nil }
        return MarkdownEdit(range: character, replacement: "", selection: NSRange(location: character.location, length: 0))
    }

    private func deletionOfReplacement(_ replacement: Replacement, in text: NSString) -> MarkdownEdit {
        var end = NSMaxRange(replacement.range)
        while end < text.length && (text.character(at: end) == 32 || text.character(at: end) == 9) { end += 1 }
        let range = NSRange(location: replacement.range.location, length: end - replacement.range.location)
        return MarkdownEdit(range: range, replacement: "", selection: NSRange(location: range.location, length: 0))
    }

    private func deletionOfWholeFormattedSpan(_ range: NSRange) -> MarkdownEdit? {
        guard spans.contains(where: { $0.range == range }),
              let opening = hiddenRanges.first(where: { NSMaxRange($0) == range.location }),
              let closing = hiddenRanges.first(where: { $0.location == NSMaxRange(range) }) else { return nil }
        let full = NSRange(location: opening.location, length: NSMaxRange(closing) - opening.location)
        return MarkdownEdit(range: full, replacement: "", selection: NSRange(location: full.location, length: 0))
    }
}
