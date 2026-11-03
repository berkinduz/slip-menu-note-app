import AppKit
import SwiftUI
import Testing
@testable import Slip
import SlipCore

@Suite("Editor layout", .serialized)
@MainActor
struct EditorLayoutTests {
    @Test("Horizontal movement is rejected while vertical scrolling remains available")
    func verticalOnlyScrolling() throws {
        _ = NSApplication.shared
        let source = String(repeating: "An action that stays inside the note panel.\n", count: 80)
        let hosting = NSHostingView(rootView: MarkdownEditor(
            text: .constant(source), noteID: UUID(), focusRequest: UUID(), isActive: true,
            initialSelection: nil, selectionChanged: { _ in }, onFocus: {}, onLinkChanged: { _ in }
        ))
        hosting.frame = NSRect(x: 0, y: 0, width: 500, height: 300)
        hosting.layoutSubtreeIfNeeded()
        let scroll = try #require(findEditorScroll(in: hosting))
        let editor = try #require(scroll.documentView as? SourceTextView)
        let container = try #require(editor.textContainer)
        editor.layoutManager?.ensureLayout(for: container)
        editor.sizeToFit()
        #expect(editor.frame.height > scroll.contentSize.height)
        let middleY = scroll.contentView.documentRect.midY - scroll.contentView.bounds.height / 2
        scroll.contentView.scroll(to: NSPoint(x: 200, y: middleY))
        #expect(scroll.contentView.bounds.minX == 0)
        #expect(scroll.contentView.bounds.minY == middleY)
        let constrained = scroll.contentView.constrainBoundsRect(scroll.contentView.bounds.offsetBy(dx: -200, dy: 10))
        #expect(constrained.minX == 0)
        #expect(abs(constrained.minY - (middleY + 10)) < 1)
        #expect(editor.string == source)
    }

    @Test("Notes wrap inside the viewport across resizing and scroller styles", arguments: [
        String(repeating: "A quick action with several words to wrap. ", count: 20),
        "```text\n" + String(repeating: "unbroken", count: 60) + "\n```\n\nhttps://example.invalid/" + String(repeating: "path", count: 60),
        "## A formatted note\n- [ ] " + String(repeating: "Türkçe 😀 **strong** and ==highlight==. ", count: 20)
    ])
    func wrapping(_ source: String) throws {
        _ = NSApplication.shared
        let hosting = NSHostingView(rootView: MarkdownEditor(
            text: .constant(source), noteID: UUID(), focusRequest: UUID(), isActive: true,
            initialSelection: nil, selectionChanged: { _ in }, onFocus: {}, onLinkChanged: { _ in }
        ))
        hosting.frame = NSRect(x: 0, y: 0, width: 500, height: 300)
        hosting.layoutSubtreeIfNeeded()
        let scroll = try #require(findEditorScroll(in: hosting))
        let editor = try #require(scroll.documentView as? SourceTextView)
        let container = try #require(editor.textContainer)
        let layout = try #require(editor.layoutManager)
        for style in [NSScroller.Style.overlay, .legacy] {
            scroll.scrollerStyle = style
            for width: CGFloat in [500, 380, 900, 500] {
                hosting.setFrameSize(NSSize(width: width, height: 300))
                hosting.layoutSubtreeIfNeeded()
                scroll.tile()
                layout.ensureLayout(for: container)
                editor.scrollRangeToVisible(NSRange(location: (source as NSString).length, length: 0))
                let constrained = scroll.contentView.constrainBoundsRect(scroll.contentView.bounds.offsetBy(dx: 200, dy: 0))
                #expect(scroll.contentSize.width > 0)
                #expect(abs(editor.frame.width - scroll.contentSize.width) < 1)
                #expect(layout.usedRect(for: container).maxX + editor.textContainerInset.width <= scroll.contentSize.width + 1)
                #expect(scroll.contentView.bounds.minX == 0)
                #expect(constrained.minX == 0)
            }
        }
        #expect(editor.string == source)
    }

    private func findEditorScroll(in view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView, scroll.documentView is SourceTextView { return scroll }
        return view.subviews.lazy.compactMap { findEditorScroll(in: $0) }.first
    }
}
