import Foundation

public enum SlashCommand: String, CaseIterable, Identifiable, Sendable {
    case heading, bullet, task, code, quote, divider, link, highlight

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .heading: "Heading"
        case .bullet: "Bulleted List"
        case .task: "Task List"
        case .code: "Code Block"
        case .quote: "Quote"
        case .divider: "Divider"
        case .link: "Link"
        case .highlight: "Highlight"
        }
    }

    public var symbol: String {
        switch self {
        case .heading: "textformat.size"
        case .bullet: "list.bullet"
        case .task: "checklist"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .quote: "text.quote"
        case .divider: "minus"
        case .link: "link"
        case .highlight: "highlighter"
        }
    }

    public static func matching(_ query: String) -> [SlashCommand] {
        let query = query.lowercased()
        return allCases.filter { command in
            let aliases: String
            switch command {
            case .heading: aliases = "heading title h1"
            case .bullet: aliases = "bullet unordered list"
            case .task: aliases = "task todo checkbox checklist"
            case .code: aliases = "code block fence"
            case .quote: aliases = "quote blockquote"
            case .divider: aliases = "divider rule line separator"
            case .link: aliases = "link url"
            case .highlight: aliases = "highlight mark"
            }
            return query.isEmpty || aliases.contains(query) || command.title.lowercased().contains(query)
        }
    }

    public func edit(in source: String, replacing range: NSRange) -> MarkdownEdit {
        var replacement: String
        var cursor: NSRange
        switch self {
        case .heading: replacement = "# "; cursor = NSRange(location: 2, length: 0)
        case .bullet: replacement = "- "; cursor = NSRange(location: 2, length: 0)
        case .task: replacement = "- [ ] "; cursor = NSRange(location: 6, length: 0)
        case .code: replacement = "```\n\n```"; cursor = NSRange(location: 4, length: 0)
        case .quote: replacement = "> "; cursor = NSRange(location: 2, length: 0)
        case .divider: replacement = "---\n"; cursor = NSRange(location: 4, length: 0)
        case .link: replacement = "[text](https://)"; cursor = NSRange(location: 1, length: 4)
        case .highlight: replacement = "==text=="; cursor = NSRange(location: 2, length: 4)
        }
        let text = source as NSString
        let line = text.lineRange(for: NSRange(location: range.location, length: 0))
        let preceding = text.substring(with: NSRange(location: line.location, length: range.location - line.location))
        if self != .link && self != .highlight && !preceding.trimmingCharacters(in: .whitespaces).isEmpty {
            replacement = "\n" + replacement
            cursor.location += 1
        }
        cursor.location += range.location
        return MarkdownEdit(range: range, replacement: replacement, selection: cursor)
    }
}

public struct SlashQuery: Equatable, Sendable {
    public let range: NSRange
    public let text: String

    public static func find(in source: String, selection: NSRange) -> SlashQuery? {
        let text = source as NSString
        guard selection.length == 0, selection.location <= text.length,
              !MarkdownDocument.isInsideFencedCode(at: selection.location, in: source) else { return nil }
        let line = text.lineRange(for: selection)
        let prefix = text.substring(with: NSRange(location: line.location, length: selection.location - line.location))
        // A slash in a URL, path, or inline code remains ordinary text.
        guard prefix.filter({ $0 == "`" }).count.isMultiple(of: 2),
              let regex = try? NSRegularExpression(pattern: #"(?:^|\s)(/([A-Za-z0-9-]*))$"#),
              let match = regex.firstMatch(in: prefix, range: NSRange(location: 0, length: (prefix as NSString).length)) else { return nil }
        let trigger = match.range(at: 1)
        let query = (prefix as NSString).substring(with: match.range(at: 2))
        return SlashQuery(range: NSRange(location: line.location + trigger.location, length: trigger.length), text: query)
    }
}
