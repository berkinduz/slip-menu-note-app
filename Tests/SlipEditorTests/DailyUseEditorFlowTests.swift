import AppKit
import SwiftUI
import Testing
@testable import Slip
import SlipCore

@Suite("Daily use editor flow", .serialized) @MainActor
struct DailyUseEditorFlowTests {
    private func key(_ code: UInt16, characters: String, flags: NSEvent.ModifierFlags = []) throws -> NSEvent {
        try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
                                      timestamp: 0, windowNumber: 0, context: nil,
                                      characters: characters, charactersIgnoringModifiers: characters,
                                      isARepeat: false, keyCode: code))
    }

    @Test func keyboardTaskAndListIndentation() throws {
        _ = NSApplication.shared
        let editor = SourceTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        editor.isEditable = true
        editor.string = "- [ ] first\n- [x] second"
        editor.setSelectedRange(NSRange(location: 7, length: 0))
        editor.keyDown(with: try key(36, characters: "\r", flags: .command))
        #expect(editor.string == "- [x] first\n- [x] second")
        editor.keyDown(with: try key(36, characters: "\r", flags: .command))
        #expect(editor.string == "- [ ] first\n- [x] second")
        editor.setSelectedRange(NSRange(location: 0, length: (editor.string as NSString).length))
        editor.keyDown(with: try key(48, characters: "\t"))
        #expect(editor.string == "  - [ ] first\n  - [x] second")
        editor.keyDown(with: try key(48, characters: "\t", flags: .shift))
        #expect(editor.string == "- [ ] first\n- [x] second")
    }

    private func scroll(in view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView, scroll.documentView is SourceTextView { return scroll }
        return view.subviews.lazy.compactMap { scroll(in: $0) }.first
    }

    @Test func searchRevealIsExplicit() async throws {
        _ = NSApplication.shared
        let body = String(repeating: "some ordinary text\n", count: 90) + "needle at the end"
        let id = UUID()
        let focus = UUID()
        func view(_ query: String, _ request: UUID?) -> MarkdownEditor {
            MarkdownEditor(text: .constant(body), noteID: id, focusRequest: focus, isActive: true,
                           initialSelection: NSRange(location: 0, length: 0), selectionChanged: { _ in },
                           onFocus: {}, onLinkChanged: { _ in }, searchQuery: query, searchRevealRequest: request)
        }
        let host = NSHostingView(rootView: view("", nil))
        host.frame = NSRect(x: 0, y: 0, width: 400, height: 220)
        let window = NSWindow(contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = host
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(50))
        let scroller = try #require(scroll(in: host))
        let editor = try #require(scroller.documentView as? SourceTextView)
        editor.setSelectedRange(NSRange(location: 0, length: 0))
        host.rootView = view("needle", nil)
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(50))
        #expect(editor.selectedRange() == NSRange(location: 0, length: 0))
        let request = UUID()
        host.rootView = view("needle", request)
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(50))
        let expected = (body as NSString).range(of: "needle")
        #expect(editor.selectedRange() == expected)
        #expect(scroller.contentView.bounds.minY > 0)
        editor.setSelectedRange(NSRange(location: 4, length: 0))
        host.rootView = view("needle", request)
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(50))
        #expect(editor.selectedRange() == NSRange(location: 4, length: 0))
    }
    @Test func savedScrollSurvivesLayoutAndFocus() async throws {
        _ = NSApplication.shared
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let session = EditorSessionStore(directory: dir)
        let id = UUID()
        session.positions[id] = EditorPosition(selection: NSRange(location: 0, length: 0), scrollOffset: 350)
        session.flush()
        let body = String(repeating: "A line with sufficient content\n", count: 100)
        func view(_ focus: UUID) -> MarkdownEditor {
            MarkdownEditor(text: .constant(body), noteID: id, focusRequest: focus, isActive: true,
                           initialSelection: NSRange(location: 0, length: 0), selectionChanged: { _ in },
                           onFocus: {}, onLinkChanged: { _ in }, session: session)
        }
        let host = NSHostingView(rootView: view(UUID()))
        host.frame = NSRect(x: 0, y: 0, width: 400, height: 220)
        let window = NSWindow(contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = host
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(80))
        let scroller = try #require(scroll(in: host))
        let editor = try #require(scroller.documentView as? SourceTextView)
        #expect(window.firstResponder === editor)
        #expect(abs(scroller.contentView.bounds.minY - 350) < 1)
        #expect(session.positions[id]?.scrollOffset == 350)
        host.rootView = view(UUID())
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(80))
        #expect(abs(scroller.contentView.bounds.minY - 350) < 1)
    }

}
