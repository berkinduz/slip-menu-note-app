import AppKit
import SwiftUI
import Testing
@testable import Slip
import SlipCore

@Suite("Editor preference application", .serialized)
@MainActor
struct EditorPreferenceTests {
    @Test("A remembered caret stays after an empty checklist prefix")
    func checklistCaret() throws {
        _ = NSApplication.shared
        let hosting = NSHostingView(rootView: MarkdownEditor(
            text: .constant("- [ ] "), noteID: UUID(), focusRequest: UUID(), isActive: true,
            initialSelection: NSRange(location: 6, length: 0), selectionChanged: { _ in }, onFocus: {}, onLinkChanged: { _ in }
        ))
        hosting.frame = NSRect(x: 0, y: 0, width: 500, height: 300)
        hosting.layoutSubtreeIfNeeded()
        let editor = try #require(findEditor(in: hosting))
        #expect(editor.selectedRange() == NSRange(location: 6, length: 0))
        editor.insertText("Send update", replacementRange: editor.selectedRange())
        #expect(editor.string == "- [ ] Send update")
    }

    @Test("Typography and writing settings affect the actual editor without changing Markdown")
    func editorControls() throws {
        _ = NSApplication.shared
        var preferences = AppPreferences()
        preferences.fontSize = 18
        preferences.lineHeight = 29
        preferences.editorPadding = 32
        preferences.paragraphSpacing = 7
        preferences.autoCorrect = true
        preferences.smartPunctuation = true
        preferences.spellChecking = false
        let source = "A **small** note.\n- [ ] Next step"
        let hosting = NSHostingView(rootView: MarkdownEditor(
            text: .constant(source), noteID: UUID(), focusRequest: UUID(), isActive: true,
            initialSelection: nil, selectionChanged: { _ in }, onFocus: {}, onLinkChanged: { _ in }
        ).environment(\.editorPreferences, preferences))
        hosting.frame = NSRect(x: 0, y: 0, width: 380, height: 300)
        hosting.layoutSubtreeIfNeeded()
        let editor = try #require(findEditor(in: hosting))
        let storage = try #require(editor.textStorage)
        let font = try #require(storage.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        let paragraph = try #require(storage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
        #expect(font.pointSize == 18)
        #expect(paragraph.minimumLineHeight == 29)
        #expect(paragraph.paragraphSpacing == 7)
        #expect(editor.textContainerInset.width == 27)
        #expect(editor.isAutomaticSpellingCorrectionEnabled)
        #expect(editor.isAutomaticQuoteSubstitutionEnabled)
        #expect(editor.isAutomaticDashSubstitutionEnabled)
        #expect(!editor.isContinuousSpellCheckingEnabled)
        #expect(editor.string == source)
    }

    @Test("The tag input consumes completion keys and leaves ordinary editing keys alone")
    func tagCompletionKeys() {
        _ = NSApplication.shared
        var moves: [Int] = []
        var added = 0
        var closed = 0
        let input = TagInput(text: .constant("work"), focusRequest: UUID(), onMove: { moves.append($0) },
                             onSubmit: { added += 1 }, onCancel: { closed += 1 })
        let coordinator = input.makeCoordinator()
        let field = NSTextField(), editor = NSTextView()
        #expect(coordinator.control(field, textView: editor, doCommandBy: #selector(NSResponder.moveDown(_:))))
        #expect(coordinator.control(field, textView: editor, doCommandBy: #selector(NSResponder.moveUp(_:))))
        #expect(coordinator.control(field, textView: editor, doCommandBy: #selector(NSResponder.insertNewline(_:))))
        #expect(coordinator.control(field, textView: editor, doCommandBy: #selector(NSResponder.cancelOperation(_:))))
        #expect(!coordinator.control(field, textView: editor, doCommandBy: #selector(NSResponder.deleteBackward(_:))))
        #expect(moves == [1, -1])
        #expect(added == 1)
        #expect(closed == 1)
    }

    private func findEditor(in view: NSView) -> SourceTextView? {
        if let editor = view as? SourceTextView { return editor }
        return view.subviews.lazy.compactMap { findEditor(in: $0) }.first
    }
}
