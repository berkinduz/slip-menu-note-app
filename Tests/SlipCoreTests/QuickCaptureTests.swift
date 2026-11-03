import Foundation
import Testing
@testable import SlipCore

@Suite("Quick capture")
struct QuickCaptureTests {
    @Test("Repeating an inline shortcut at its end continues typing outside the hidden markers")
    func finishInlineFormatting() {
        for (action, source, caret) in [(MarkdownAction.bold, "**bold**", 6), (.italic, "_italic_", 7), (.code, "`code`", 5)] {
            let edit = MarkdownEditing.edit(action, in: source, selection: NSRange(location: caret, length: 0))
            #expect(edit.applying(to: source) == source)
            #expect(edit.selection == NSRange(location: (source as NSString).length, length: 0))
        }
    }

    @Test("Formatting toggles off when a rendered whole selection includes hidden delimiters")
    func wholeRenderedSelection() {
        for (action, source, expected) in [(MarkdownAction.bold, "**bold**", "bold"), (.italic, "_italic_", "italic"), (.code, "`code`", "code")] {
            let edit = MarkdownEditing.edit(action, in: source, selection: NSRange(location: 0, length: (source as NSString).length))
            #expect(edit.applying(to: source) == expected)
        }
    }

    @Test("English letter shortcuts also recognize Turkish dotted and dotless I")
    func turkishShortcut() {
        for key in ["i", "I", "ı", "İ"] {
            #expect(ShortcutKey.canonical(key) == "i")
        }
        #expect(ShortcutKey.canonical("B") == "b")
        #expect(ShortcutKey.canonical("s") == "s")
    }

    @Test("A title is optional; untitled notes are identified by their first content line")
    func optionalTitle() {
        let note = Note(body: "\n# A quick thought\n\nMore details")
        #expect(note.title.isEmpty)
        #expect(note.displayTitle == "A quick thought")
        #expect(note.exportedMarkdown == "\n# A quick thought\n\nMore details\n")
        #expect(Note(title: "My title", body: "First line").displayTitle == "My title")
        #expect(Note().displayTitle == "New note")
    }

    @Test("Slash queries start after whitespace and retain UTF-16 source positions")
    func query() throws {
        let start = try #require(SlashQuery.find(in: "/", selection: NSRange(location: 1, length: 0)))
        #expect(start.text == "")
        #expect(start.range == NSRange(location: 0, length: 1))
        let unicode = try #require(SlashQuery.find(in: "📝 /ta", selection: NSRange(location: 6, length: 0)))
        #expect(unicode.text == "ta")
        #expect(unicode.range == NSRange(location: 3, length: 3))
        #expect(SlashCommand.matching(unicode.text) == [.task])
    }

    @Test("URLs, paths, selected text, and code remain literal")
    func literalSlashes() {
        for source in ["https://example.com/task", "some/path/heading", "`/task", "```sh\n/task", "~~~\n/task"] {
            #expect(SlashQuery.find(in: source, selection: NSRange(location: (source as NSString).length, length: 0)) == nil)
        }
        #expect(SlashQuery.find(in: "/task", selection: NSRange(location: 0, length: 5)) == nil)
    }

    @Test("Each quick command replaces the trigger with editable Markdown")
    func insertion() {
        let expected: [(SlashCommand, String, NSRange)] = [
            (.heading, "# ", NSRange(location: 2, length: 0)),
            (.bullet, "- ", NSRange(location: 2, length: 0)),
            (.task, "- [ ] ", NSRange(location: 6, length: 0)),
            (.code, "```\n\n```", NSRange(location: 4, length: 0)),
            (.quote, "> ", NSRange(location: 2, length: 0)),
            (.divider, "---\n", NSRange(location: 4, length: 0)),
            (.link, "[text](https://)", NSRange(location: 1, length: 4))
        ]
        for (command, markdown, selection) in expected {
            let source = "/" + command.rawValue
            let edit = command.edit(in: source, replacing: NSRange(location: 0, length: (source as NSString).length))
            #expect(edit.applying(to: source) == markdown)
            #expect(edit.selection == selection)
        }
    }

    @Test("Block commands entered after a sentence start a new line")
    func inlineBlock() {
        let source = "An idea /task"
        let edit = SlashCommand.task.edit(in: source, replacing: NSRange(location: 8, length: 5))
        #expect(edit.applying(to: source) == "An idea \n- [ ] ")
        #expect(edit.selection == NSRange(location: 15, length: 0))
    }

    @Test("Return inside fenced code does not continue a literal list")
    func literalCodeLists() {
        for source in ["```yaml\n- item", "~~~\n1. item", "````\n```\n- item"] {
            #expect(MarkdownEditing.continuation(in: source, selection: NSRange(location: (source as NSString).length, length: 0)) == nil)
        }
        let closed = "```\n- code\n```\n- item"
        #expect(MarkdownEditing.continuation(in: closed, selection: NSRange(location: (closed as NSString).length, length: 0))?.applying(to: closed) == closed + "\n- ")
    }
    @Test("Highlight wraps and exits at the content end")
    func highlightEditing() {
        let wrapped = MarkdownEditing.edit(.highlight, in: "😀", selection: NSRange(location: 0, length: 2))
        #expect(wrapped.applying(to: "😀") == "==😀==")
        #expect(wrapped.selection == NSRange(location: 2, length: 2))
        let exit = MarkdownEditing.edit(.highlight, in: "==text==", selection: NSRange(location: 6, length: 0))
        #expect(exit.applying(to: "==text==") == "==text==")
        #expect(exit.selection == NSRange(location: 8, length: 0))
        let command = SlashCommand.highlight.edit(in: "idea /highlight", replacing: NSRange(location: 5, length: 10))
        #expect(command.applying(to: "idea /highlight") == "idea ==text==")
        #expect(command.selection == NSRange(location: 7, length: 4))
        #expect(SlashCommand.matching("highlight").contains(.highlight))
    }

}
