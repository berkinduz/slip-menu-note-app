import Foundation

public enum MarkdownAction: String, CaseIterable, Sendable {
    case bold, italic, highlight, heading, bullet, task, link, code
}

public struct MarkdownEdit: Equatable, Sendable {
    public let range: NSRange
    public let replacement: String
    public let selection: NSRange

    public init(range: NSRange, replacement: String, selection: NSRange) {
        self.range = range
        self.replacement = replacement
        self.selection = selection
    }

    public func applying(to source: String) -> String {
        (source as NSString).replacingCharacters(in: range, with: replacement)
    }
}

public enum MarkdownEditing {
    public static func edit(_ action: MarkdownAction, in source: String, selection: NSRange) -> MarkdownEdit {
        let text = source as NSString
        let range = NSIntersectionRange(selection, NSRange(location: 0, length: text.length))
        let selected = text.substring(with: range)
        switch action {
        case .bold: return wrap("**", source: text, range: range)
        case .italic: return wrap("_", source: text, range: range)
        case .highlight: return wrap("==", source: text, range: range)
        case .code:
            return selected.contains("\n") ? wrap("```\n", suffix: "\n```", source: text, range: range) : wrap("`", source: text, range: range)
        case .link:
            let label = selected.isEmpty ? "link text" : selected
            return MarkdownEdit(range: range, replacement: "[\(label)](https://)", selection: NSRange(location: range.location + (label as NSString).length + 3, length: 8))
        case .heading: return prefixLines("# ", source: text, range: range)
        case .bullet: return prefixLines("- ", source: text, range: range)
        case .task: return prefixLines("- [ ] ", source: text, range: range)
        }
    }

    public static func continuation(in source: String, selection: NSRange) -> MarkdownEdit? {
        let text = source as NSString
        guard selection.length == 0, selection.location <= text.length,
              !MarkdownDocument.isInsideFencedCode(at: selection.location, in: source) else { return nil }
        let lineRange = text.lineRange(for: selection)
        let prefixRange = NSRange(location: lineRange.location, length: selection.location - lineRange.location)
        let line = text.substring(with: prefixRange)
        guard let regex = try? NSRegularExpression(pattern: #"^(\s*)([-*+]|\d+[.)])\s+(?:\[([ xX])\]\s+)?(.*)$"#),
              let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) else { return nil }
        let ns = line as NSString
        let indent = ns.substring(with: match.range(at: 1))
        let marker = ns.substring(with: match.range(at: 2))
        let content = ns.substring(with: match.range(at: 4))
        if content.trimmingCharacters(in: .whitespaces).isEmpty {
            return MarkdownEdit(range: prefixRange, replacement: "", selection: NSRange(location: lineRange.location, length: 0))
        }
        var nextMarker = marker
        if let last = marker.last, let value = Int(marker.dropLast()) { nextMarker = "\(value + 1)\(last)" }
        let checkbox = match.range(at: 3).location != NSNotFound ? "[ ] " : ""
        let replacement = "\n\(indent)\(nextMarker) \(checkbox)"
        return MarkdownEdit(range: selection, replacement: replacement, selection: NSRange(location: selection.location + (replacement as NSString).length, length: 0))
    }

    public static func toggleTask(in source: String, selection: NSRange) -> MarkdownEdit? {
        let text = source as NSString
        guard selection.location <= text.length, !MarkdownDocument.isInsideFencedCode(at: selection.location, in: source) else { return nil }
        let line = text.lineRange(for: NSRange(location: selection.location, length: 0))
        let value = text.substring(with: line)
        let regex = try! NSRegularExpression(pattern: #"^[ \t]*[-*+] +\[([ xX])\]"#)
        guard let match = regex.firstMatch(in: value, range: NSRange(location: 0, length: (value as NSString).length)) else { return nil }
        let marker = match.range(at: 1)
        let character = (value as NSString).substring(with: marker)
        return MarkdownEdit(range: NSRange(location: line.location + marker.location, length: 1), replacement: character == " " ? "x" : " ", selection: selection)
    }

    public static func indentList(in source: String, selection: NSRange, outdent: Bool) -> MarkdownEdit? {
        let text = source as NSString
        guard selection.location <= text.length, NSMaxRange(selection) <= text.length else { return nil }
        let target = selection.length > 0 ? NSRange(location: selection.location, length: selection.length - 1) : selection
        let range = text.lineRange(for: target)
        let original = text.substring(with: range)
        let regex = try! NSRegularExpression(pattern: #"^[ \t]*(?:[-*+]|\d+[.)]) +"#)
        var offset = range.location
        var changes: [(location: Int, removed: Int, inserted: Int)] = []
        let lines = original.components(separatedBy: "\n")
        let result = lines.map { line -> String in
            defer { offset += (line as NSString).length + 1 }
            guard !line.isEmpty, !MarkdownDocument.isInsideFencedCode(at: offset, in: source), regex.firstMatch(in: line, range: NSRange(location: 0, length: (line as NSString).length)) != nil else { return line }
            if !outdent { changes.append((offset, 0, 2)); return "  " + line }
            if line.hasPrefix("  ") { changes.append((offset, 2, 0)); return String(line.dropFirst(2)) }
            if line.hasPrefix(" ") || line.hasPrefix("\t") { changes.append((offset, 1, 0)); return String(line.dropFirst()) }
            return line
        }.joined(separator: "\n")
        guard !changes.isEmpty else { return nil }
        func mapped(_ position: Int) -> Int {
            var delta = 0
            for change in changes where change.location <= position {
                if position < change.location + change.removed { return change.location + delta + change.inserted }
                delta += change.inserted - change.removed
            }
            return position + delta
        }
        let start = mapped(selection.location)
        let end = mapped(NSMaxRange(selection))
        return MarkdownEdit(range: range, replacement: result, selection: NSRange(location: start, length: max(0, end - start)))
    }

    public static func pasteURL(_ url: String, in source: String, selection: NSRange) -> MarkdownEdit? {
        let text = source as NSString
        guard selection.length > 0, selection.location <= text.length, NSMaxRange(selection) <= text.length,
              !MarkdownDocument.isInsideFencedCode(at: selection.location, in: source),
              let components = URLComponents(string: url), let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme), components.host != nil,
              url.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return nil }
        let label = text.substring(with: selection)
        let destination = url.replacingOccurrences(of: "(", with: "%28").replacingOccurrences(of: ")", with: "%29")
        let replacement = "[\(label)](\(destination))"
        return MarkdownEdit(range: selection, replacement: replacement, selection: NSRange(location: selection.location + (replacement as NSString).length, length: 0))
    }

    private static func wrap(_ prefix: String, suffix: String? = nil, source: NSString, range: NSRange) -> MarkdownEdit {
        let suffix = suffix ?? prefix
        let prefixLength = (prefix as NSString).length
        let suffixLength = (suffix as NSString).length
        let selected = source.substring(with: range)
        let style: MarkdownPresentation.Style? = prefix == "**" ? .strong : prefix == "_" ? .emphasis : prefix == "`" ? .code : prefix == "==" ? .highlight : nil
        let presentation = MarkdownPresentation(source: source as String)
        if range.length == 0, let style,
           presentation.spans.contains(where: { $0.style == style && NSMaxRange($0.range) == range.location }),
           let closing = presentation.hiddenRanges.first(where: { $0.location == range.location && $0.length == suffixLength }),
           source.substring(with: closing) == suffix {
            return MarkdownEdit(range: range, replacement: "", selection: NSRange(location: NSMaxRange(closing), length: 0))
        }
        if range.length >= prefixLength + suffixLength, selected.hasPrefix(prefix), selected.hasSuffix(suffix) {
            let content = NSRange(location: range.location + prefixLength, length: range.length - prefixLength - suffixLength)
            if let style, presentation.spans.contains(where: { $0.range == content && $0.style == style }) {
                return MarkdownEdit(range: range, replacement: source.substring(with: content), selection: NSRange(location: range.location, length: content.length))
            }
        }
        if range.location >= prefixLength && NSMaxRange(range) + suffixLength <= source.length,
           source.substring(with: NSRange(location: range.location - prefixLength, length: prefixLength)) == prefix,
           source.substring(with: NSRange(location: NSMaxRange(range), length: suffixLength)) == suffix {
            return MarkdownEdit(range: NSRange(location: range.location - prefixLength, length: range.length + prefixLength + suffixLength), replacement: selected, selection: NSRange(location: range.location - prefixLength, length: range.length))
        }
        let value = selected.isEmpty ? "text" : selected
        return MarkdownEdit(range: range, replacement: prefix + value + suffix, selection: NSRange(location: range.location + prefixLength, length: (value as NSString).length))
    }

    private static func prefixLines(_ prefix: String, source: NSString, range: NSRange) -> MarkdownEdit {
        // A selection ending at the next line's start does not include that next line.
        let target = range.length > 0 ? NSRange(location: range.location, length: range.length - 1) : range
        let lineRange = source.lineRange(for: target)
        let original = source.substring(with: lineRange)
        let trailingNewline = original.hasSuffix("\n")
        let value = trailingNewline ? String(original.dropLast()) : original
        let lines = value.components(separatedBy: "\n")
        let removing = lines.allSatisfy { $0.hasPrefix(prefix) }
        let replacement = lines.map { removing ? String($0.dropFirst(prefix.count)) : prefix + $0 }.joined(separator: "\n") + (trailingNewline ? "\n" : "")
        return MarkdownEdit(range: lineRange, replacement: replacement, selection: NSRange(location: lineRange.location, length: (replacement as NSString).length))
    }
}
