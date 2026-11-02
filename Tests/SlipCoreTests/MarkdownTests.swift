import Foundation
import Testing
@testable import SlipCore

@Suite("Markdown notebook")
struct MarkdownTests {
    @Test("Preview recognizes headings, paragraphs, quotes, tasks, lists, and rules")
    func blocks() {
        let blocks = MarkdownDocument.parse("# A thought\n\nKeep **this**.\n\n> Slow down.\n\n- [ ] Try it\n- [x] Done\n- An idea\n\n---")
        #expect(blocks.map(\.kind) == [
            .heading(level: 1, text: "A thought"), .paragraph("Keep **this**."),
            .quote("Slow down."), .task(checked: false, text: "Try it", indent: 0),
            .task(checked: true, text: "Done", indent: 0),
            .listItem(marker: "•", text: "An idea", indent: 0), .divider
        ])
        #expect(blocks[3].id == 6)
    }

    @Test("Fenced code keeps Markdown-looking lines literal")
    func codeFence() {
        let blocks = MarkdownDocument.parse("```swift\n# literal\n- [ ] code\n```\n\nEnd")
        #expect(blocks.map(\.kind) == [.code(language: "swift", text: "# literal\n- [ ] code"), .paragraph("End")])
    }

    @Test("Unclosed code fences still render what has been typed")
    func unfinishedFence() {
        #expect(MarkdownDocument.parse("~~~\nlet a = 1").first?.kind == .code(language: "", text: "let a = 1"))
    }

    @Test("Tables retain header and row columns")
    func tables() {
        let source = "| Name | Status |\n| :--- | ---: |\n| Slip | Ready |\n| Draft | WIP |"
        #expect(MarkdownDocument.parse(source).first?.kind == .table(headers: ["Name", "Status"], rows: [["Slip", "Ready"], ["Draft", "WIP"]]))
    }

    @Test("Nested list indentation and ordered numbers remain visible")
    func nestedLists() {
        #expect(MarkdownDocument.parse("1. First\n   - Nested").map(\.kind) == [
            .listItem(marker: "1.", text: "First", indent: 0),
            .listItem(marker: "•", text: "Nested", indent: 3)
        ])
    }

    @Test("Setext headings and Windows line endings are supported")
    func setextAndCRLF() {
        #expect(MarkdownDocument.parse("Title\r\n===\r\n\r\nText").map(\.kind) == [.heading(level: 1, text: "Title"), .paragraph("Text")])
    }

    @Test("Checking a task edits only its source checkbox")
    func taskMutation() {
        let source = "# Tasks\n\n- [ ] First\n- [X] Second\n"
        #expect(MarkdownDocument.togglingTask(at: 2, in: source) == "# Tasks\n\n- [x] First\n- [X] Second\n")
        #expect(MarkdownDocument.togglingTask(at: 3, in: source) == "# Tasks\n\n- [ ] First\n- [ ] Second\n")
        #expect(MarkdownDocument.togglingTask(at: 0, in: source) == source)
    }

    @Test("Formatting uses UTF-16 ranges so emoji do not shift the selection")
    func formatting() {
        let source = "📝 a thought"
        let range = (source as NSString).range(of: "thought")
        let edit = MarkdownEditing.edit(.bold, in: source, selection: range)
        #expect(edit.applying(to: source) == "📝 a **thought**")
        #expect(edit.selection == NSRange(location: 7, length: 7))
    }

    @Test("Bold toggles off when markers already surround the selection")
    func toggleBold() {
        let edit = MarkdownEditing.edit(.bold, in: "**hello**", selection: NSRange(location: 2, length: 5))
        #expect(edit.applying(to: "**hello**") == "hello")
        #expect(edit.selection == NSRange(location: 0, length: 5))
    }

    @Test("Task formatting applies to every selected line")
    func taskFormatting() {
        let source = "One\nTwo"
        let edit = MarkdownEditing.edit(.task, in: source, selection: NSRange(location: 0, length: 7))
        #expect(edit.applying(to: source) == "- [ ] One\n- [ ] Two")
    }

    @Test("Enter continues tasks unchecked and increments ordered lists")
    func listContinuation() throws {
        let task = "- [x] Finished"
        let taskEdit = try #require(MarkdownEditing.continuation(in: task, selection: NSRange(location: 14, length: 0)))
        #expect(taskEdit.applying(to: task) == "- [x] Finished\n- [ ] ")
        let ordered = "9. Item"
        let orderedEdit = try #require(MarkdownEditing.continuation(in: ordered, selection: NSRange(location: 7, length: 0)))
        #expect(orderedEdit.applying(to: ordered) == "9. Item\n10. ")
    }

    @Test("Enter leaves an empty list and ordinary paragraphs use native input")
    func endList() throws {
        let source = "- First\n- "
        let edit = try #require(MarkdownEditing.continuation(in: source, selection: NSRange(location: 10, length: 0)))
        #expect(edit.applying(to: source) == "- First\n")
        #expect(MarkdownEditing.continuation(in: "Plain", selection: NSRange(location: 5, length: 0)) == nil)
    }
}
