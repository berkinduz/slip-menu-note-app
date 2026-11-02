import Foundation

public struct MarkdownBlock: Identifiable, Equatable, Sendable {
    public let id: Int
    public let kind: Kind

    public enum Kind: Equatable, Sendable {
        case heading(level: Int, text: String)
        case paragraph(String)
        case quote(String)
        case task(checked: Bool, text: String, indent: Int)
        case listItem(marker: String, text: String, indent: Int)
        case code(language: String, text: String)
        case divider
        case table(headers: [String], rows: [[String]])
    }
}

public enum MarkdownDocument {
    public static func isInsideFencedCode(at utf16Location: Int, in source: String) -> Bool {
        let text = source as NSString
        let prefix = text.substring(to: min(max(0, utf16Location), text.length))
        var opening: (marker: Character, count: Int)?
        for line in prefix.components(separatedBy: "\n") {
            let indentation = line.prefix(while: { $0 == " " || $0 == "\t" })
            guard indentation.reduce(0, { $0 + ($1 == "\t" ? 4 : 1) }) <= 3 else { continue }
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let marker = trimmed.first, marker == "`" || marker == "~" else { continue }
            let count = trimmed.prefix(while: { $0 == marker }).count
            guard count >= 3 else { continue }
            if let current = opening {
                if current.marker == marker, count >= current.count,
                   trimmed.dropFirst(count).trimmingCharacters(in: .whitespaces).isEmpty { opening = nil }
            } else {
                opening = (marker, count)
            }
        }
        return opening != nil
    }

    public static func parse(_ source: String) -> [MarkdownBlock] {
        let lines = source.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var result: [MarkdownBlock] = []
        var index = 0
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { index += 1; continue }
            let start = index

            if let fence = captures(#"^\s{0,3}(`{3,}|~{3,})(.*)$"#, line) {
                let marker = fence[0]
                var code: [String] = []
                index += 1
                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                    if candidate.count >= marker.count && candidate.allSatisfy({ $0 == marker.first }) { break }
                    code.append(lines[index]); index += 1
                }
                result.append(MarkdownBlock(id: start, kind: .code(language: fence[1].trimmingCharacters(in: .whitespaces), text: code.joined(separator: "\n"))))
                if index < lines.count { index += 1 }
                continue
            }

            if index + 1 < lines.count && line.contains("|") && isTableDivider(lines[index + 1]) {
                let headers = cells(line)
                var rows: [[String]] = []
                index += 2
                while index < lines.count && lines[index].contains("|") && !lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
                    rows.append(cells(lines[index])); index += 1
                }
                result.append(MarkdownBlock(id: start, kind: .table(headers: headers, rows: rows)))
                continue
            }

            if index + 1 < lines.count, let underline = captures(#"^\s{0,3}(=+|-+)\s*$"#, lines[index + 1]) {
                result.append(MarkdownBlock(id: start, kind: .heading(level: underline[0].hasPrefix("=") ? 1 : 2, text: trimmed)))
                index += 2; continue
            }

            if let heading = captures(#"^\s{0,3}(#{1,6})\s+(.+?)(?:\s+#+\s*)?$"#, line) {
                result.append(MarkdownBlock(id: start, kind: .heading(level: heading[0].count, text: heading[1])))
            } else if isRule(trimmed) {
                result.append(MarkdownBlock(id: start, kind: .divider))
            } else if captures(#"^\s{0,3}>\s?(.*)$"#, line) != nil {
                var quote: [String] = []
                while index < lines.count, let part = captures(#"^\s{0,3}>\s?(.*)$"#, lines[index]) {
                    quote.append(part[0]); index += 1
                }
                result.append(MarkdownBlock(id: start, kind: .quote(quote.joined(separator: "\n"))))
                continue
            } else if let task = captures(#"^(\s*)[-*+]\s+\[([ xX])\]\s*(.*)$"#, line) {
                result.append(MarkdownBlock(id: start, kind: .task(checked: task[1].lowercased() == "x", text: task[2], indent: indentation(task[0]))))
            } else if let item = captures(#"^(\s*)([-*+]|\d+[.)])\s+(.*)$"#, line) {
                let marker = item[1].first?.isNumber == true ? item[1] : "•"
                result.append(MarkdownBlock(id: start, kind: .listItem(marker: marker, text: item[2], indent: indentation(item[0]))))
            } else {
                var paragraph = [line]
                index += 1
                while index < lines.count && !lines[index].trimmingCharacters(in: .whitespaces).isEmpty && !startsBlock(lines[index]) {
                    if index + 1 < lines.count && isTableDivider(lines[index + 1]) { break }
                    paragraph.append(lines[index]); index += 1
                }
                result.append(MarkdownBlock(id: start, kind: .paragraph(paragraph.joined(separator: "\n"))))
                continue
            }
            index += 1
        }
        return result
    }

    public static func togglingTask(at lineIndex: Int, in source: String) -> String {
        let newline = source.contains("\r\n") ? "\r\n" : "\n"
        var lines = source.components(separatedBy: newline)
        guard lines.indices.contains(lineIndex),
              let regex = try? NSRegularExpression(pattern: #"^\s*[-*+]\s+\[([ xX])\]"#),
              let match = regex.firstMatch(in: lines[lineIndex], range: NSRange(location: 0, length: (lines[lineIndex] as NSString).length)) else { return source }
        let range = match.range(at: 1)
        let line = lines[lineIndex] as NSString
        lines[lineIndex] = line.replacingCharacters(in: range, with: line.substring(with: range) == " " ? "x" : " ")
        return lines.joined(separator: newline)
    }

    private static func captures(_ pattern: String, _ value: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: value, range: NSRange(location: 0, length: (value as NSString).length)) else { return nil }
        let text = value as NSString
        return (1..<match.numberOfRanges).map { match.range(at: $0).location == NSNotFound ? "" : text.substring(with: match.range(at: $0)) }
    }

    private static func indentation(_ whitespace: String) -> Int { whitespace.reduce(0) { $0 + ($1 == "\t" ? 4 : 1) } }

    private static func isRule(_ line: String) -> Bool {
        let compact = line.filter { !$0.isWhitespace }
        return compact.count >= 3 && ["*", "-", "_"].contains(String(compact.prefix(1))) && compact.allSatisfy { $0 == compact.first }
    }

    private static func startsBlock(_ line: String) -> Bool {
        isRule(line) || captures(#"^\s*(#{1,6}\s|>|[-*+]\s|\d+[.)]\s|`{3,}|~{3,})(.*)$"#, line) != nil
    }

    private static func cells(_ line: String) -> [String] {
        var text = line.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("|") { text.removeFirst() }
        if text.hasSuffix("|") && !text.hasSuffix("\\|") { text.removeLast() }
        var result: [String] = [], cell = "", escaped = false
        for character in text {
            if character == "|" && !escaped { result.append(cell.trimmingCharacters(in: .whitespaces)); cell = "" }
            else { cell.append(character) }
            escaped = character == "\\" && !escaped
        }
        result.append(cell.trimmingCharacters(in: .whitespaces))
        return result
    }

    private static func isTableDivider(_ line: String) -> Bool {
        let values = cells(line)
        return !values.isEmpty && values.allSatisfy { $0.range(of: #"^:?-{3,}:?$"#, options: .regularExpression) != nil }
    }
}
