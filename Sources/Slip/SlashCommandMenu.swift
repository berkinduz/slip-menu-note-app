import AppKit
import Observation
import SwiftUI
import SlipCore

@MainActor @Observable
private final class SlashMenuState {
    var commands: [SlashCommand] = []
    var selected: SlashCommand = .heading
}

@MainActor private final class SlashSuggestionPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor final class SlashCommandMenu {
    private weak var editor: SourceTextView?
    private let state = SlashMenuState()
    private var panel: SlashSuggestionPanel?
    private var context: SlashQuery?
    private var dismissedLocation: Int?
    private var isApplying = false

    init(editor: SourceTextView) { self.editor = editor }

    func update() {
        guard !isApplying else { return }
        guard let editor, editor.editorPreferences.slashCommands, editor.isEditable, !editor.hasMarkedText(),
              editor.window?.firstResponder === editor,
              let query = SlashQuery.find(in: editor.string, selection: editor.selectedRange()) else {
            dismissedLocation = nil
            hide()
            return
        }
        guard dismissedLocation != query.range.location else { hide(); return }
        let commands = SlashCommand.matching(query.text)
        guard !commands.isEmpty else { hide(); return }
        if context?.range.location != query.range.location || !commands.contains(state.selected) {
            state.selected = commands[0]
        }
        context = query
        state.commands = commands
        show(beside: editor)
    }

    func handle(_ event: NSEvent) -> Bool {
        guard panel?.isVisible == true,
              event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return false }
        switch event.keyCode {
        case 125: move(by: 1)
        case 126: move(by: -1)
        case 36, 76, 48: choose(state.selected)
        case 53: _ = dismissIfVisible()
        default: return false
        }
        return true
    }

    func dismissIfVisible() -> Bool {
        guard panel?.isVisible == true else { return false }
        dismissedLocation = context?.range.location
        hide()
        return true
    }

    func hide() {
        panel?.orderOut(nil)
        if let panel { panel.parent?.removeChildWindow(panel) }
        context = nil
    }

    private func move(by direction: Int) {
        guard !state.commands.isEmpty else { return }
        let index = state.commands.firstIndex(of: state.selected) ?? 0
        state.selected = state.commands[(index + direction + state.commands.count) % state.commands.count]
    }

    private func choose(_ command: SlashCommand) {
        guard let editor, let query = SlashQuery.find(in: editor.string, selection: editor.selectedRange()) else { hide(); return }
        isApplying = true
        defer { isApplying = false }
        if command == .link {
            hide()
            editor.presentLinkEditor(replacing: query.range)
            return
        }
        let edit = command.edit(in: editor.string, replacing: query.range)
        hide()
        editor.apply(edit)
        editor.window?.makeFirstResponder(editor)
    }

    private func show(beside editor: SourceTextView) {
        guard let owner = editor.window else { return }
        if panel == nil {
            let window = SlashSuggestionPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.level = .popUpMenu
            window.setAccessibilityLabel("quick commands")
            panel = window
        }
        guard let panel else { return }
        let root = SlashMenuHost(style: editor.editorStyle, state: state) { [weak self] in self?.choose($0) }
        if let hosting = panel.contentView as? NSHostingView<SlashMenuHost> { hosting.rootView = root }
        else { panel.contentView = NSHostingView(rootView: root) }
        panel.appearance = owner.appearance
        let caret = editor.firstRect(forCharacterRange: editor.selectedRange(), actualRange: nil)
        let width: CGFloat = 246
        let height = CGFloat(state.commands.count) * 31 + 12
        var origin = NSPoint(x: caret.minX, y: caret.minY - height - 5)
        if let visible = owner.screen?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - width - 8)
            if origin.y < visible.minY + 8 { origin.y = caret.maxY + 5 }
        }
        panel.setFrame(NSRect(origin: origin, size: NSSize(width: width, height: height)), display: true)
        if panel.parent !== owner { owner.addChildWindow(panel, ordered: .above) }
        panel.orderFront(nil)
    }
}

private struct SlashMenuHost: View {
    let style: SlipStyle
    let state: SlashMenuState
    let choose: (SlashCommand) -> Void
    var body: some View {
        SlashMenuView(state: state, choose: choose)
            .environment(\.slipStyle, style)
            .foregroundStyle(style.text)
    }
}

private struct SlashMenuView: View {
    @Environment(\.slipStyle) private var style
    @Bindable var state: SlashMenuState
    let choose: (SlashCommand) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(state.commands) { command in
                Button { choose(command) } label: {
                    HStack(spacing: 9) {
                        Image(systemName: command.symbol).font(.system(size: 12)).frame(width: 21)
                            .foregroundStyle(state.selected == command ? style.accent : style.secondary)
                        Text(command.title).font(.system(size: 12))
                        Spacer()
                        if state.selected == command {
                            Image(systemName: "return").font(.system(size: 10)).foregroundStyle(style.secondary)
                        }
                    }
                    .padding(.horizontal, 8).frame(height: 31)
                    .background(state.selected == command ? style.popupSelection : .clear, in: RoundedRectangle(cornerRadius: 5))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { if $0 { state.selected = command } }
                .accessibilityAddTraits(state.selected == command ? .isSelected : [])
            }

        }
        .padding(6)
        .background(style.popup)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(style.line, lineWidth: 0.7))
        .tint(style.accent)
    }
}
