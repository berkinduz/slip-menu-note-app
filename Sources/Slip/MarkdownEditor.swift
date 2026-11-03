import AppKit
import SwiftUI
import SlipCore

struct MarkdownEditor: NSViewRepresentable {
    @Environment(\.slipStyle) private var style
    @Environment(\.editorPreferences) private var preferences
    @Binding var text: String
    let noteID: UUID
    let focusRequest: UUID
    let isActive: Bool
    let initialSelection: NSRange?
    let selectionChanged: (NSRange) -> Void
    let onFocus: () -> Void
    let onLinkChanged: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true

        let storage = NSTextStorage()
        let layout = MarkdownGlyphLayout()
        let container = NSTextContainer(containerSize: NSSize(width: 450, height: CGFloat.greatestFiniteMagnitude))
        storage.addLayoutManager(layout)
        layout.addTextContainer(container)
        let editor = SourceTextView(frame: NSRect(x: 0, y: 0, width: 450, height: 300), textContainer: container)
        editor.isRichText = false
        editor.allowsUndo = true
        editor.isEditable = true
        editor.isSelectable = true
        editor.drawsBackground = false
        editor.editorPreferences = preferences
        editor.editorStyle = style
        editor.font = EditorTypography.font(preferences)
        editor.textColor = style.textColor
        editor.insertionPointColor = style.theme == .kanagawaDragon ? style.textColor : style.accentColor
        editor.selectedTextAttributes = [.backgroundColor: style.selectionColor, .foregroundColor: style.textColor]
        editor.linkTextAttributes = [.foregroundColor: style.linkColor, .underlineStyle: NSUnderlineStyle.single.rawValue]
        editor.usesAdaptiveColorMappingForDarkAppearance = style.theme != .kanagawaDragon
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticLinkDetectionEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.isContinuousSpellCheckingEnabled = preferences.spellChecking
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.minSize = .zero
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.textContainerInset = NSSize(width: 23, height: 14)
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.containerSize = NSSize(width: 450, height: CGFloat.greatestFiniteMagnitude)
        editor.string = text
        editor.delegate = context.coordinator
        editor.onFocus = onFocus
        editor.onLinkChanged = onLinkChanged
        editor.setAccessibilityLabel("Markdown Editor")
        editor.setAccessibilityHelp("Write a note in Markdown. Changes save automatically.")
        let length = (text as NSString).length
        editor.setSelectedRange(initialSelection.map { NSIntersectionRange($0, NSRange(location: 0, length: length)) } ?? NSRange(location: length, length: 0))
        SyntaxHighlighter.apply(to: editor)
        scroll.documentView = editor
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let editor = scroll.documentView as? SourceTextView else { return }
        context.coordinator.parent = self
        if editor.editorPreferences != preferences || editor.editorStyle != style {
            editor.editorPreferences = preferences
            editor.editorStyle = style
            editor.isContinuousSpellCheckingEnabled = preferences.spellChecking
            editor.textColor = style.textColor
            editor.insertionPointColor = style.theme == .kanagawaDragon ? style.textColor : style.accentColor
            editor.selectedTextAttributes = [.backgroundColor: style.selectionColor, .foregroundColor: style.textColor]
            editor.linkTextAttributes = [.foregroundColor: style.linkColor, .underlineStyle: NSUnderlineStyle.single.rawValue]
            editor.usesAdaptiveColorMappingForDarkAppearance = style.theme != .kanagawaDragon
            if !preferences.slashCommands { editor.hideSlashCommands() }
            SyntaxHighlighter.apply(to: editor)
        }
        editor.isEditable = isActive
        editor.isSelectable = true
        if !isActive {
            editor.hideSlashCommands()
            if editor.window?.firstResponder === editor { editor.window?.makeFirstResponder(nil) }
        }
        if editor.string != text {
            let selection = initialSelection ?? editor.selectedRange()
            context.coordinator.isUpdating = true
            editor.string = text
            editor.setSelectedRange(NSIntersectionRange(selection, NSRange(location: 0, length: (text as NSString).length)))
            SyntaxHighlighter.apply(to: editor)
            context.coordinator.isUpdating = false
        }
        if context.coordinator.lastFocusRequest != focusRequest {
            context.coordinator.lastFocusRequest = focusRequest
            if isActive {
                DispatchQueue.main.async { [weak editor] in
                    guard let editor, editor.isEditable, let window = editor.window, window.isVisible else { return }
                    window.makeFirstResponder(editor)
                    editor.scrollRangeToVisible(editor.selectedRange())
                }
            }
        }
    }

    @MainActor final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownEditor
        var isUpdating = false
        var lastFocusRequest: UUID?

        init(_ parent: MarkdownEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdating, let editor = notification.object as? NSTextView else { return }
            parent.text = editor.string
            SyntaxHighlighter.apply(to: editor)
            (editor as? SourceTextView)?.updateSlashCommands()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isUpdating, let editor = notification.object as? NSTextView else { return }
            parent.selectionChanged(editor.selectedRange())
            (editor as? SourceTextView)?.updateSlashCommands()
        }

        func textView(_ textView: NSTextView, willChangeSelectionFromCharacterRange oldSelectedCharRange: NSRange, toCharacterRange newSelectedCharRange: NSRange) -> NSRange {
            guard !isUpdating, let editor = textView as? SourceTextView,
                  editor.presentation.source == editor.string else { return newSelectedCharRange }
            return editor.presentation.adjustedSelection(from: oldSelectedCharRange, to: newSelectedCharRange)
        }
    }
}

@MainActor final class SourceTextView: NSTextView {
    var editorPreferences = AppPreferences()
    var editorStyle: SlipStyle = .system
    private lazy var slashCommands = SlashCommandMenu(editor: self)
    var onFocus: (() -> Void)?
    var onLinkChanged: ((Bool) -> Void)?
    private var linkEditor: LinkEditorController?
    var presentation: MarkdownPresentation {
        (layoutManager as? MarkdownGlyphLayout)?.presentation ?? MarkdownPresentation(source: string)
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { onFocus?() }
        return accepted
    }

    override func keyDown(with event: NSEvent) {
        if slashCommands.handle(event) { return }
        if event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty,
           selectedRange().length == 0, event.keyCode == 123 || event.keyCode == 124 {
            let position = presentation.movingCaret(in: string, from: selectedRange().location, direction: event.keyCode == 123 ? -1 : 1)
            setSelectedRange(NSRange(location: position, length: 0))
            scrollRangeToVisible(selectedRange())
            return
        }
        super.keyDown(with: event)
    }

    override func deleteBackward(_ sender: Any?) {
        guard isEditable else { return }
        if let edit = presentation.backwardDeletion(in: string, selection: selectedRange()) { apply(edit) }
        else { super.deleteBackward(sender) }
    }

    override func deleteForward(_ sender: Any?) {
        guard isEditable else { return }
        if let edit = presentation.forwardDeletion(in: string, selection: selectedRange()) { apply(edit) }
        else { super.deleteForward(sender) }
    }

    override func copy(_ sender: Any?) {
        let text = presentation.visibleText(in: string, range: selectedRange())
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    override func cut(_ sender: Any?) {
        guard isEditable else { return }
        copy(sender)
        if let edit = presentation.backwardDeletion(in: string, selection: selectedRange()) { apply(edit) }
        else { insertText("", replacementRange: selectedRange()) }
    }

    override func mouseDown(with event: NSEvent) {
        if isEditable, let layoutManager, let textContainer {
            let point = convert(event.locationInWindow, from: nil)
            for replacement in presentation.replacements where replacement.taskChecked != nil {
                guard let taskLayout = layoutManager as? MarkdownGlyphLayout else { continue }
                let box = taskLayout.taskCheckboxRect(for: replacement, in: textContainer)
                let rect = box.offsetBy(dx: textContainerOrigin.x, dy: textContainerOrigin.y)
                    .insetBy(dx: -max(4, (22 - box.width) / 2), dy: -max(3, (20 - box.height) / 2))
                if rect.contains(point) {
                    let raw = string as NSString
                    let marker = raw.substring(with: replacement.range) as NSString
                    let box = marker.range(of: #"\[[ xX]\]"#, options: .regularExpression)
                    if box.location != NSNotFound {
                        let selection = selectedRange()
                        insertText(replacement.taskChecked == true ? " " : "x", replacementRange: NSRange(location: replacement.range.location + box.location + 1, length: 1))
                        setSelectedRange(selection)
                        return
                    }
                }
            }
        }
        super.mouseDown(with: event)
    }

    override func resignFirstResponder() -> Bool {
        slashCommands.hide()
        return super.resignFirstResponder()
    }

    func updateSlashCommands() { slashCommands.update() }
    func hideSlashCommands() { slashCommands.hide() }
    func dismissSlashCommands() -> Bool { slashCommands.dismissIfVisible() }
    func closeLinkEditor() { linkEditor?.close() }

    func format(_ action: MarkdownAction) {
        guard isEditable else { return }
        hideSlashCommands()
        if action == .link { presentLinkEditor() }
        else {
            apply(MarkdownEditing.edit(action, in: string, selection: selectedRange()))
            window?.makeFirstResponder(self)
        }
    }

    func presentLinkEditor(replacing triggerRange: NSRange? = nil) {
        guard isEditable, window != nil else { return }
        closeLinkEditor()
        let original = string
        let raw = original as NSString
        var target = triggerRange ?? selectedRange()
        var rawLabel = triggerRange == nil ? raw.substring(with: target) : ""
        var url = ""
        if triggerRange == nil,
           let span = presentation.spans.first(where: {
               if case .link = $0.style { return target.location >= $0.range.location && NSMaxRange(target) <= NSMaxRange($0.range) }
               return false
           }), case .link(let destination) = span.style,
           let opening = presentation.hiddenRanges.first(where: { NSMaxRange($0) == span.range.location }),
           let closing = presentation.hiddenRanges.first(where: { $0.location == NSMaxRange(span.range) }) {
            target = NSRange(location: opening.location, length: NSMaxRange(closing) - opening.location)
            rawLabel = raw.substring(with: span.range)
            url = destination
        }
        let label = MarkdownPresentation(source: rawLabel).visibleText(in: rawLabel, range: NSRange(location: 0, length: (rawLabel as NSString).length))
        let sourceLabel = rawLabel
        let replaceRange = target
        let controller = LinkEditorController(text: label, url: url, style: editorStyle) { [weak self] text, url in
            guard let self, self.isEditable, self.window?.isVisible == true, self.string == original else { return }
            let label = text == label ? sourceLabel : text
            let destination = url.replacingOccurrences(of: "(", with: "%28").replacingOccurrences(of: ")", with: "%29")
            let markdown = "[\(label)](\(destination))"
            self.insertText(markdown, replacementRange: replaceRange)
            self.setSelectedRange(NSRange(location: replaceRange.location + (markdown as NSString).length, length: 0))
            self.window?.makeFirstResponder(self)
        } onClose: { [weak self] in
            self?.onLinkChanged?(false)
            self?.linkEditor = nil
        }
        linkEditor = controller
        onLinkChanged?(true)
        controller.show(for: self)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { closeLinkEditor() }
    }

    override func insertNewline(_ sender: Any?) {
        if editorPreferences.continueLists, !hasMarkedText(), let edit = MarkdownEditing.continuation(in: string, selection: selectedRange()) {
            apply(edit)
        } else { super.insertNewline(sender) }
    }

    func apply(_ edit: MarkdownEdit) {
        insertText(edit.replacement, replacementRange: edit.range)
        setSelectedRange(edit.selection)
        scrollRangeToVisible(edit.selection)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        SyntaxHighlighter.apply(to: self)
    }
}

@MainActor private enum SyntaxHighlighter {

    static func apply(to editor: NSTextView) {
        guard let storage = editor.textStorage else { return }
        let source = editor as? SourceTextView
        let preferences = source?.editorPreferences ?? AppPreferences()
        let colors = source?.editorStyle ?? .system
        let font = EditorTypography.font(preferences)
        let full = NSRange(location: 0, length: storage.length)
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = preferences.lineHeight
        paragraph.maximumLineHeight = preferences.lineHeight
        paragraph.defaultTabInterval = 28
        let base: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: colors.textColor, .paragraphStyle: paragraph,
            .ligature: preferences.fontLigatures ? 1 : 0
        ]
        storage.beginEditing()
        storage.setAttributes(base, range: full)
        let presentation = MarkdownPresentation(source: storage.string)
        for span in presentation.spans where span.range.length > 0 {
            switch span.style {
            case .strong: addTrait(.boldFontMask, to: storage, range: span.range)
            case .emphasis:
                addTrait(.italicFontMask, to: storage, range: span.range)
                storage.addAttribute(.foregroundColor, value: colors.italicColor, range: span.range)
            case .strikethrough: storage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: span.range)
            case .highlight:
                storage.addAttributes([.backgroundColor: colors.highlightBackgroundColor, .foregroundColor: colors.highlightTextColor], range: span.range)
            case .code:
                let codeFont = font.isFixedPitch ? font : NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .regular)
                storage.addAttributes([.foregroundColor: colors.codeColor, .font: codeFont], range: span.range)
            case .link(let destination):
                storage.addAttribute(.foregroundColor, value: colors.linkColor, range: span.range)
                if let url = URL(string: destination) { storage.addAttribute(.link, value: url, range: span.range) }
            case .heading(let level):
                let headingFont = EditorTypography.font(preferences, size: preferences.fontSize + (level == 1 ? 8 : level == 2 ? 5 : 2))
                storage.addAttributes([.font: NSFontManager.shared.convert(headingFont, toHaveTrait: .boldFontMask), .foregroundColor: colors.headingColor], range: span.range)
                let headingParagraph = paragraph.mutableCopy() as! NSMutableParagraphStyle
                headingParagraph.minimumLineHeight = max(preferences.lineHeight, headingFont.pointSize * 1.5)
                headingParagraph.maximumLineHeight = headingParagraph.minimumLineHeight
                storage.addAttribute(.paragraphStyle, value: headingParagraph, range: (storage.string as NSString).lineRange(for: span.range))
            case .quote:
                addTrait(.italicFontMask, to: storage, range: span.range)
                storage.addAttribute(.foregroundColor, value: colors.secondaryColor, range: span.range)
            case .fence: storage.addAttribute(.foregroundColor, value: colors.quoteColor, range: span.range)
            case .rule: storage.addAttribute(.foregroundColor, value: colors.secondaryColor.withAlphaComponent(0.35), range: span.range)
            }
        }
        for replacement in presentation.replacements {
            storage.addAttributes([
                .font: MarkdownGlyphLayout.fontForReplacement(replacement.text, basedOn: font),
                .foregroundColor: colors.accentColor
            ], range: replacement.range)
        }
        storage.endEditing()
        if let layout = editor.layoutManager as? MarkdownGlyphLayout {
            layout.taskCheckColor = colors.canvasColor
            layout.update(presentation: presentation)
        }
        editor.typingAttributes = base
    }

    private static func addTrait(_ trait: NSFontTraitMask, to storage: NSTextStorage, range: NSRange) {
        var runs: [(NSRange, NSFont)] = []
        storage.enumerateAttribute(.font, in: range) { value, range, _ in
            if let font = value as? NSFont { runs.append((range, font)) }
        }
        for (range, font) in runs {
            storage.addAttribute(.font, value: NSFontManager.shared.convert(font, toHaveTrait: trait), range: range)
        }
    }
}
