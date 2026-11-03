import AppKit
import SwiftUI

struct SearchField: NSViewRepresentable {
    @Environment(\.slipStyle) private var style
    @Binding var text: String
    let focusRequest: UUID?
    let onFocus: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> SearchTextField {
        let field = SearchTextField()
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 12)
        field.textColor = style.textColor
        field.placeholderString = "Search"
        field.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.stringValue = text
        field.delegate = context.coordinator
        field.onFocus = onFocus
        field.setAccessibilityLabel("Search Notes")
        field.setAccessibilityHelp("Search notes or #tags (⌘F)")
        return field
    }

    func updateNSView(_ field: SearchTextField, context: Context) {
        context.coordinator.parent = self
        field.onFocus = onFocus
        field.textColor = style.textColor
        if field.stringValue != text { field.stringValue = text }
        if let focusRequest, context.coordinator.lastRequest != focusRequest {
            context.coordinator.lastRequest = focusRequest
            field.requestFocus()
        }
    }

    @MainActor final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SearchField
        var lastRequest: UUID?
        init(_ parent: SearchField) { self.parent = parent }
        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }
    }
}

@MainActor final class SearchTextField: NSTextField {
    var onFocus: (() -> Void)?
    private var wantsFocus = false

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { onFocus?() }
        return accepted
    }

    func requestFocus() { wantsFocus = true; focusWhenAttached() }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        focusWhenAttached()
    }

    private func focusWhenAttached() {
        guard wantsFocus, window != nil else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.wantsFocus, let window = self.window, window.isVisible else { return }
            self.wantsFocus = false
            window.makeFirstResponder(self)
            self.selectText(nil)
        }
    }
}
