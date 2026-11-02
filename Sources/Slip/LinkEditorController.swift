import AppKit

@MainActor final class LinkEditorController: NSViewController, NSTextFieldDelegate {
    private let textField = NSTextField()
    private let urlField = NSTextField()
    private let applyButton = NSButton()
    private var sheet: NSWindow?
    private weak var owner: NSWindow?
    private let style: SlipStyle
    private let initialText: String
    private let initialURL: String
    private let onApply: (String, String) -> Void
    private let onClose: () -> Void

    init(text: String, url: String, style: SlipStyle, onApply: @escaping (String, String) -> Void, onClose: @escaping () -> Void) {
        initialText = text
        initialURL = url
        self.style = style
        self.onApply = onApply
        self.onClose = onClose
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 138))
        view.wantsLayer = true
        view.layer?.backgroundColor = style.canvasColor.cgColor
        addField(textField, label: "text", value: initialText, y: 91)
        addField(urlField, label: "url", value: initialURL, y: 57)
        urlField.placeholderString = "https://example.com"
        applyButton.title = "apply"
        applyButton.bezelStyle = .rounded
        applyButton.frame = NSRect(x: 249, y: 13, width: 78, height: 28)
        applyButton.keyEquivalent = "\r"
        applyButton.target = self
        applyButton.action = #selector(applyLink(_:))
        applyButton.isEnabled = !initialURL.isEmpty
        view.addSubview(applyButton)
        let cancelButton = NSButton(title: "cancel", target: self, action: #selector(cancelLink(_:)))
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.frame = NSRect(x: 165, y: 13, width: 78, height: 28)
        view.addSubview(cancelButton)
        preferredContentSize = view.frame.size
    }

    private func addField(_ field: NSTextField, label: String, value: String, y: CGFloat) {
        let caption = NSTextField(labelWithString: label)
        caption.font = .systemFont(ofSize: 11)
        caption.textColor = style.secondaryColor
        caption.frame = NSRect(x: 15, y: y + 4, width: 38, height: 18)
        view.addSubview(caption)
        field.stringValue = value
        field.font = .systemFont(ofSize: 12)
        field.frame = NSRect(x: 55, y: y, width: 261, height: 26)
        field.usesSingleLineMode = true
        field.delegate = self
        field.target = self
        field.action = #selector(applyLink(_:))
        field.setAccessibilityLabel("Link \(label)")
        view.addSubview(field)
    }

    func show(for editor: NSView) {
        guard let owner = editor.window else { return }
        self.owner = owner
        let sheet = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 340, height: 138), styleMask: [.titled], backing: .buffered, defer: false)
        sheet.title = "link"
        sheet.titleVisibility = .hidden
        sheet.titlebarAppearsTransparent = true
        sheet.isReleasedWhenClosed = false
        sheet.appearance = owner.appearance
        sheet.contentViewController = self
        sheet.setAccessibilityLabel("edit link")
        self.sheet = sheet
        owner.beginSheet(sheet) { [weak self] _ in self?.didClose() }
        sheet.makeFirstResponder(initialText.isEmpty ? textField : urlField)
    }

    func close() {
        guard let sheet else { return }
        owner?.endSheet(sheet)
    }

    private func didClose() {
        let closedSheet = sheet
        sheet = nil
        onClose()
        closedSheet?.contentViewController = nil
    }

    @objc private func cancelLink(_ sender: Any?) { close() }

    func controlTextDidChange(_ notification: Notification) {
        applyButton.isEnabled = !urlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @objc private func applyLink(_ sender: Any?) {
        let value = urlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        let url = URL(string: value)?.scheme == nil ? "https://" + value : value
        let label = textField.stringValue.isEmpty ? value : textField.stringValue
        close()
        onApply(label, url)
    }
}
