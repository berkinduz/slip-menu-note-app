import AppKit
import SwiftUI

struct OptionalTitleField: NSViewRepresentable {
    @Environment(\.slipStyle) private var style
    @Environment(\.isEnabled) private var isEnabled
    @Binding var text: String
    let requestsFocus: Bool
    let onBeginEditing: () -> Void
    let onSubmit: () -> Void
    let onEndEditing: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> TitleTextField {
        let field = TitleTextField()
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 25, weight: .semibold)
        field.textColor = style.textColor
        field.placeholderString = "title (optional)"
        field.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.stringValue = text
        field.isEditable = isEnabled
        field.delegate = context.coordinator
        field.setAccessibilityLabel("note title (optional)")
        return field
    }

    func updateNSView(_ field: TitleTextField, context: Context) {
        context.coordinator.parent = self
        field.isEditable = isEnabled
        field.textColor = style.textColor
        if field.stringValue != text { field.stringValue = text }
        if requestsFocus && !context.coordinator.didRequestFocus {
            context.coordinator.didRequestFocus = true
            field.requestInitialFocus()
        } else if !requestsFocus {
            context.coordinator.didRequestFocus = false
            field.cancelInitialFocus()
        }
    }

    @MainActor final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: OptionalTitleField
        var didRequestFocus = false

        init(_ parent: OptionalTitleField) { self.parent = parent }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func controlTextDidBeginEditing(_ notification: Notification) { parent.onBeginEditing() }
        func controlTextDidEndEditing(_ notification: Notification) { parent.onEndEditing() }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard commandSelector == #selector(NSResponder.insertNewline(_:)) else { return false }
            parent.onSubmit()
            return true
        }
    }
}

@MainActor final class TitleTextField: NSTextField {
    private var wantsInitialFocus = false

    func requestInitialFocus() {
        wantsInitialFocus = true
        focusWhenAttached()
    }

    func cancelInitialFocus() { wantsInitialFocus = false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        focusWhenAttached()
    }

    private func focusWhenAttached() {
        guard wantsInitialFocus, window != nil else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.wantsInitialFocus, let window = self.window, window.isVisible else { return }
            self.wantsInitialFocus = false
            window.makeFirstResponder(self)
        }
    }
}
