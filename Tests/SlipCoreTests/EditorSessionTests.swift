import Foundation
import Testing
@testable import SlipCore

@Test @MainActor func editorSessionPersistsPositionsAndSize() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let id = UUID()
    let store = EditorSessionStore(directory: dir)
    store.positions[id] = EditorPosition(selection: NSRange(location: 3, length: 2), scrollOffset: 120)
    store.panelWidth = 700
    store.panelHeight = 500
    store.flush()
    let restored = EditorSessionStore(directory: dir)
    #expect(restored.positions[id]?.selection == NSRange(location: 3, length: 2))
    #expect(restored.positions[id]?.scrollOffset == 120)
    #expect(restored.panelWidth == 700 && restored.panelHeight == 500)
}

@Test func editorTaskToggleAndFencedCode() throws {
    let source = "- [ ] hello\n- [x] done\n```\n- [ ] code\n```"
    let first = try #require(MarkdownEditing.toggleTask(in: source, selection: NSRange(location: 8, length: 0)))
    #expect(first.applying(to: source).hasPrefix("- [x] hello"))
    let second = try #require(MarkdownEditing.toggleTask(in: source, selection: NSRange(location: 19, length: 0)))
    #expect(second.applying(to: source).contains("- [ ] done"))
    #expect(MarkdownEditing.toggleTask(in: source, selection: NSRange(location: 35, length: 0)) == nil)
}

@Test func editorListIndentAndUnicodeLink() throws {
    let source = "- one\n- two\n"
    let edit = try #require(MarkdownEditing.indentList(in: source, selection: NSRange(location: 0, length: 11), outdent: false))
    #expect(edit.applying(to: source) == "  - one\n  - two\n")
    let out = try #require(MarkdownEditing.indentList(in: edit.applying(to: source), selection: edit.selection, outdent: true))
    #expect(out.applying(to: edit.applying(to: source)) == source)
    let link = try #require(MarkdownEditing.pasteURL("https://example.com", in: "👋 café", selection: NSRange(location: 3, length: 4)))
    #expect(link.applying(to: "👋 café") == "👋 [café](https://example.com)")
}

@Test func editorIndentSkipsFencedLinesAndRetainsCaret() throws {
    let source = "- first\n```\n- code\n```\n- last"
    let all = NSRange(location: 0, length: (source as NSString).length)
    let edit = try #require(MarkdownEditing.indentList(in: source, selection: all, outdent: false))
    #expect(edit.applying(to: source) == "  - first\n```\n- code\n```\n  - last")
    let caret = try #require(MarkdownEditing.indentList(in: "- hello", selection: NSRange(location: 4, length: 0), outdent: false))
    #expect(caret.selection == NSRange(location: 6, length: 0))
    #expect(MarkdownEditing.pasteURL("file:///tmp/a", in: "text", selection: NSRange(location: 0, length: 4)) == nil)
    #expect(MarkdownEditing.pasteURL("https://example.com", in: "```\ntext\n```", selection: NSRange(location: 4, length: 4)) == nil)
}

@Test func editorPastedURLWithParenthesesPreservesRenderedDestination() throws {
    let url = "https://en.wikipedia.org/wiki/Foo_(bar)"
    let edit = try #require(MarkdownEditing.pasteURL(url, in: "Read", selection: NSRange(location: 0, length: 4)))
    let markdown = edit.applying(to: "Read")
    let presentation = MarkdownPresentation(source: markdown)
    let destination = try #require(presentation.spans.compactMap { span -> String? in
        if case .link(let target) = span.style { return target }
        return nil
    }.first)
    #expect(URL(string: destination) == URL(string: "https://en.wikipedia.org/wiki/Foo_%28bar%29"))
    #expect(presentation.visibleText(in: markdown, range: NSRange(location: 0, length: (markdown as NSString).length)) == "Read")
}
