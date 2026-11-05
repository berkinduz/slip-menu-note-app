import AppKit
import Testing
@testable import Slip
import SlipCore

@Suite("Editor commands", .serialized) @MainActor
struct EditorCommandTests {
    @Test func unicodeLinkUndo() throws {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
        let editor = SourceTextView(frame: window.contentView!.bounds)
        editor.allowsUndo = true
        window.contentView?.addSubview(editor)
        window.makeFirstResponder(editor)
        editor.string = "👋 café"
        editor.setSelectedRange(NSRange(location: 3, length: 4))
        let edit = try #require(MarkdownEditing.pasteURL("https://example.com", in: editor.string, selection: editor.selectedRange()))
        editor.apply(edit)
        #expect(editor.string == "👋 [café](https://example.com)")
        editor.undoManager?.undo()
        #expect(editor.string == "👋 café")
    }
}
