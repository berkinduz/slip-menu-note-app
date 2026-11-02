import SwiftUI
import SlipCore

struct ContentView: View {
    @Environment(\.slipStyle) private var style
    @Bindable var workspace: Workspace

    var body: some View {
        HStack(spacing: 0) {
            if workspace.sidebarVisible {
                SidebarView(workspace: workspace).frame(width: 212)
                Rectangle().fill(style.line).frame(width: 0.5)
            }
            VStack(spacing: 0) {
                HStack(spacing: 3) {
                    IconButton(symbol: "sidebar.left", label: "notes (⇧⌘s)") { workspace.toggleSidebar() }
                    Spacer()
                    IconButton(symbol: "square.and.pencil", label: "new note (⌘n)") { workspace.newNote() }
                        .disabled(!workspace.notebook.canWrite)
                    NoteMenu(workspace: workspace)
                }
                .padding(.horizontal, 10).frame(height: 40)

                if let error = workspace.notebook.errorMessage {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                        Text(error).textSelection(.enabled)
                        Spacer(minLength: 0)
                        Button("show files") { workspace.revealStorage() }
                    }
                    .font(.system(size: 11)).foregroundStyle(.orange)
                    .padding(12).background(Color.orange.opacity(0.07))
                }
                if let note = workspace.notebook.selectedNote {
                    NoteDetailView(workspace: workspace, note: note).id(note.id)
                } else {
                    Spacer()
                    Text(workspace.filter == .trash ? "trash is empty" : "no note selected")
                        .font(.system(size: 12)).foregroundStyle(style.secondary)
                    Spacer()
                }
            }
            .frame(minWidth: 320, maxWidth: .infinity, maxHeight: .infinity)
            .background(style.canvas)
        }
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).strokeBorder(style.line, lineWidth: 0.7))
        .overlay(alignment: .bottom) {
            if let message = workspace.transientMessage {
                Text(message).font(.system(size: 11)).foregroundStyle(style.text)
                    .padding(.horizontal, 11).padding(.vertical, 7)
                    .background(style.popup, in: Capsule()).padding(.bottom, 12)
                    .allowsHitTesting(false)
            }
        }
        .sheet(isPresented: $workspace.showGuide) { MarkdownGuideView() }
        .alert("empty trash?", isPresented: $workspace.confirmEmptyTrash) {
            Button("cancel", role: .cancel) { }
            Button("delete permanently", role: .destructive) { workspace.notebook.emptyTrash() }
        } message: { Text("notes in trash will be permanently deleted.") }
        .alert("couldn’t export note", isPresented: Binding(get: { workspace.operationError != nil }, set: { if !$0 { workspace.operationError = nil } })) {
            Button("ok", role: .cancel) { workspace.operationError = nil }
        } message: { Text(workspace.operationError ?? "") }
    }
}

private struct NoteDetailView: View {
    @Environment(\.slipStyle) private var style
    @Bindable var workspace: Workspace
    let note: Note
    @State private var isEditingTitle = false

    private var bodyBinding: Binding<String> {
        Binding(get: { workspace.notebook.library.notes.first { $0.id == note.id }?.body ?? "" }, set: { workspace.notebook.updateNote(note.id, body: $0) })
    }

    var body: some View {
        VStack(spacing: 0) {
            if note.deletedAt != nil {
                HStack {
                    Text("in trash")
                    Spacer()
                    Button("restore") { workspace.restore(note.id) }.foregroundStyle(style.accent)
                }
                .font(.system(size: 11)).foregroundStyle(style.secondary)
                .padding(.horizontal, 28).padding(.vertical, 8)
            }
            if !note.title.isEmpty || isEditingTitle {
                OptionalTitleField(
                    text: Binding(
                        get: { workspace.notebook.library.notes.first { $0.id == note.id }?.title ?? "" },
                        set: { workspace.notebook.updateNote(note.id, title: $0) }
                    ),
                    requestsFocus: isEditingTitle,
                    onBeginEditing: {
                        if workspace.inputFocus != .title { workspace.inputFocus = .title }
                    },
                    onSubmit: { isEditingTitle = false; workspace.focusBody() },
                    onEndEditing: { isEditingTitle = false }
                )
                .disabled(note.deletedAt != nil)
                .frame(height: 32).padding(.horizontal, 28).padding(.top, 10).padding(.bottom, 9)
            }

            ZStack(alignment: .topLeading) {
                MarkdownEditor(
                    text: bodyBinding, noteID: note.id, focusRequest: workspace.focusRequest,
                    isActive: note.deletedAt == nil,
                    initialSelection: workspace.editorSelections[note.id],
                    selectionChanged: { workspace.editorSelections[note.id] = $0 },
                    onFocus: {
                        if workspace.inputFocus != .body { workspace.inputFocus = .body }
                    },
                    onLinkChanged: { workspace.isEditingLink = $0 }
                )
                if note.body.isEmpty && note.deletedAt == nil {
                    Text("write a note…").font(.system(size: 14)).foregroundStyle(style.tertiary)
                        .padding(.leading, 28).padding(.top, 14)
                        .allowsHitTesting(false).accessibilityHidden(true)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)

            Button { workspace.showTags = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "number").font(.system(size: 9))
                    Text(note.allTags.isEmpty ? "add tag" : note.allTags.joined(separator: "  ·  "))
                        .font(.system(size: 10)).lineLimit(1).truncationMode(.tail)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(style.secondary)
                .padding(.horizontal, 27).frame(height: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain).disabled(note.deletedAt != nil)
            .accessibilityLabel(note.allTags.isEmpty ? "add tags" : "edit tags: \(note.allTags.joined(separator: ", "))")
            .help("edit tags")
            .overlay(alignment: .top) { Hairline().padding(.horizontal, 24) }
            .popover(isPresented: $workspace.showTags, arrowEdge: .bottom) {
                TagEditorView(workspace: workspace, noteID: note.id)
            }
        }
        .onChange(of: workspace.titleRequest) {
            workspace.inputFocus = .title
            isEditingTitle = true
        }
    }
}

struct NoteMenu: View {
    @Environment(\.slipStyle) private var style
    @Bindable var workspace: Workspace

    var body: some View {
        Menu {
            if let note = workspace.notebook.selectedNote {
                if note.deletedAt == nil {
                    Button(note.title.isEmpty ? "add title…" : "edit title…") { workspace.editTitle() }
                    Button("tags…") { workspace.showTags = true }
                    Button(note.isPinned ? "unpin" : "pin") { workspace.notebook.togglePin(note.id) }
                } else {
                    Button("restore") { workspace.restore(note.id) }
                }
                Menu("export") {
                    Button("copy markdown") { workspace.copyMarkdown() }
                    Button("markdown file…") { workspace.exportNote() }
                }
                if note.deletedAt == nil {
                    Button("move to trash", role: .destructive) { workspace.trash(note.id) }
                }
                Divider()
            }
            Menu("notes") {
                Button("all notes") { workspace.query = ""; workspace.changeFilter(.all); showSidebar() }
                Button("pinned") { workspace.query = ""; workspace.changeFilter(.pinned); showSidebar() }
                if !workspace.notebook.library.tags.isEmpty {
                    Menu("tags") {
                        ForEach(workspace.notebook.library.tags, id: \.self) { tag in
                            Button(tag) { workspace.query = ""; workspace.changeFilter(.tag(tag)); showSidebar() }
                        }
                    }
                }
                Divider()
                Button("trash") { workspace.query = ""; workspace.changeFilter(.trash); showSidebar() }
                if !workspace.notebook.library.filtered(by: .trash).isEmpty {
                    Button("empty trash…", role: .destructive) { workspace.confirmEmptyTrash = true }
                }
            }
            Button("settings…") { workspace.openSettings() }.keyboardShortcut(",")
            Button("keyboard shortcuts") { workspace.showGuide = true }
            Divider()
            Button("quit slip") { NSApp.terminate(nil) }.keyboardShortcut("q")
        } label: {
            Image(systemName: "ellipsis").font(.system(size: 14, weight: .medium)).foregroundStyle(style.secondary).frame(width: 28, height: 28)
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        .help("more").accessibilityLabel("more")
    }

    private func showSidebar() { if !workspace.sidebarVisible { workspace.toggleSidebar() } }
}
