import AppKit
import SwiftUI

/// Handles completion keys in the field editor, before NSTextField consumes them.
struct TagInput: NSViewRepresentable {
    @Environment(\.slipStyle) private var style
    @Binding var text: String
    let focusRequest: UUID
    var placeholder = "Add or find a tag"
    var onMove: ((Int) -> Void)?
    let onSubmit: () -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> SearchTextField {
        let field = SearchTextField()
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 13)
        field.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.placeholderString = placeholder
        field.setAccessibilityLabel("Tag name")
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ field: SearchTextField, context: Context) {
        context.coordinator.parent = self
        field.textColor = style.textColor
        if field.stringValue != text { field.stringValue = text }
        if context.coordinator.lastFocus != focusRequest {
            context.coordinator.lastFocus = focusRequest
            field.requestFocus()
        }
    }

    @MainActor final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: TagInput
        var lastFocus: UUID?
        init(_ parent: TagInput) { self.parent = parent }
        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }
        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.moveDown(_:)):
                guard let move = parent.onMove else { return false }
                move(1)
            case #selector(NSResponder.moveUp(_:)):
                guard let move = parent.onMove else { return false }
                move(-1)
            case #selector(NSResponder.insertNewline(_:)): parent.onSubmit()
            case #selector(NSResponder.cancelOperation(_:)): parent.onCancel()
            default: return false
            }
            return true
        }
    }
}
