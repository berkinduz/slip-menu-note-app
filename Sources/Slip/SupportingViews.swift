import SwiftUI
import SlipCore

struct TagEditorView: View {
    @Environment(\.slipStyle) private var style
    @Bindable var workspace: Workspace
    let noteID: UUID
    @State private var draft = ""
    @FocusState private var tagFocused: Bool

    private var note: Note? { workspace.notebook.library.notes.first { $0.id == noteID } }
    private var suggestions: [String] {
        let term = Note.normalizedTags([draft]).first ?? ""
        return Array(workspace.notebook.library.tags.filter { tag in
            !(note?.tags.contains(tag) ?? false) && (term.isEmpty || tag.localizedStandardContains(term))
        }.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("tags").font(.system(size: 14, weight: .semibold))
                Spacer()
                Button("done") { addDraft(); workspace.showTags = false }
                    .buttonStyle(.plain).font(.system(size: 12, weight: .medium)).foregroundStyle(style.accent)
            }
            HStack(spacing: 7) {
                Image(systemName: "number").foregroundStyle(style.secondary)
                TextField("add a tag…", text: $draft).textFieldStyle(.plain)
                    .focused($tagFocused).onSubmit { addDraft() }
                Button { addDraft() } label: { Image(systemName: "return").foregroundStyle(style.secondary) }
                    .buttonStyle(.plain).disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("add tag")
            }
            .font(.system(size: 12)).padding(9)
            .background(style.text.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))

            if let note, !note.tags.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(note.tags, id: \.self) { tag in
                            HStack {
                                TagPill(tag: tag)
                                Spacer()
                                IconButton(symbol: "xmark", label: "remove \(tag) tag", size: 24) {
                                    workspace.notebook.updateNote(noteID, tags: note.tags.filter { $0 != tag })
                                }
                            }
                        }
                    }
                }
                .frame(height: min(180, CGFloat(note.tags.count) * 28))
            }
            if !suggestions.isEmpty {
                Hairline()
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(suggestions, id: \.self) { tag in
                        Button {
                            add(tag)
                            draft = ""
                        } label: {
                            Label(tag, systemImage: "number").font(.system(size: 12)).foregroundStyle(style.secondary)
                                .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 4)
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16).frame(width: 260)
        .defaultFocus($tagFocused, true)
    }

    private func add(_ value: String) {
        guard let note else { return }
        workspace.notebook.updateNote(noteID, tags: note.tags + [value])
    }

    private func addDraft() {
        guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        add(draft)
        draft = ""
    }
}

struct MarkdownGuideView: View {
    @Environment(\.slipStyle) private var style
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                SlipMark(size: 35)
                VStack(alignment: .leading, spacing: 3) {
                    Text("keyboard shortcuts").font(.system(size: 19, weight: .semibold)).tracking(-0.5)
                }
                Spacer()
                IconButton(symbol: "xmark", label: "close guide") { dismiss() }
            }.padding(24)
            Hairline()
            ScrollView {
                VStack(alignment: .leading, spacing: 19) {
                    VStack(spacing: 11) {
                        shortcut("quick commands", "/")
                        shortcut("open or hide slip", "⌃⌥N")
                        shortcut("new note", "⌘N")
                        shortcut("find a note", "⌘F")
                        shortcut("settings", "⌘,")
                        shortcut("show / hide sidebar", "⇧⌘S")
                        shortcut("close and save", "esc")
                    }
                    Hairline()
                    Text("a little markdown").font(.system(size: 14, weight: .semibold))
                    VStack(spacing: 11) {
                        syntax("# A heading", "headings", "⌘⇧H")
                        syntax("**bold**", "bold", "⌘B")
                        syntax("_italic_", "italic", "⌘I")
                        syntax("==highlight==", "highlight", "⌘⇧M")
                        syntax("- A list item", "bullet list", "⌘⇧L")
                        syntax("- [ ] A task", "task list", "⌘⇧T")
                        syntax("[text](url)", "link", "⌘K")
                        syntax("`code`", "inline code", "⌘E")
                    }
                    Text("type / to insert a heading, list, task, code block, quote, divider, or link. keep typing to filter; use ↑↓ and return to choose. esc dismisses the menu. return continues a list; return again on an empty item ends it.")
                        .font(.system(size: 11)).lineSpacing(4).foregroundStyle(style.secondary)
                }.padding(24)
            }
            Hairline()
            HStack {
                Label("your notes stay on this mac.", systemImage: "internaldrive")
                    .font(.system(size: 11)).foregroundStyle(style.secondary)
                Spacer()
                Button("got it") { dismiss() }.keyboardShortcut(.defaultAction)
            }.padding(.horizontal, 24).padding(.vertical, 15)
        }
        .frame(width: 465, height: 560)
        .background(style.canvas)
    }

    private func shortcut(_ title: String, _ keys: String) -> some View {
        HStack { Text(title).font(.system(size: 12)); Spacer(); KeyCap(text: keys) }
    }
    private func syntax(_ source: String, _ name: String, _ keys: String) -> some View {
        HStack {
            Text(source).font(.system(size: 11, design: .monospaced)).foregroundStyle(style.accent).frame(width: 160, alignment: .leading)
            Text(name).font(.system(size: 11)).foregroundStyle(style.secondary)
            Spacer()
            KeyCap(text: keys)
        }
    }
}
