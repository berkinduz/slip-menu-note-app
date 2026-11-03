import SwiftUI
import SlipCore

struct FolderPrompt: Identifiable {
    let id = UUID()
    let folderID: UUID?
    let parentID: UUID?
    let name: String
}

struct FolderEditorView: View {
    @Environment(\.slipStyle) private var style
    @Bindable var workspace: Workspace
    let prompt: FolderPrompt
    @State private var name: String
    @FocusState private var nameFocused: Bool

    init(workspace: Workspace, prompt: FolderPrompt) {
        self.workspace = workspace
        self.prompt = prompt
        _name = State(initialValue: prompt.name)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(prompt.folderID == nil ? "New folder" : "Rename folder")
                .font(.headline)
            if let parentID = prompt.parentID {
                Text("In \(workspace.notebook.library.folderPath(parentID))")
                    .font(.caption).foregroundStyle(style.secondary)
            }
            TextField("Folder name", text: $name)
                .textFieldStyle(.roundedBorder).focused($nameFocused)
                .onSubmit(save)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { workspace.folderPrompt = nil }
                    .keyboardShortcut(.cancelAction)
                Button(prompt.folderID == nil ? "Create" : "Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(22).frame(width: 300)
        .foregroundStyle(style.text).background(style.popup)
        .onAppear { nameFocused = true }
    }

    private func save() {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        workspace.saveFolder(prompt, name: name)
    }
}

struct MoveNoteMenu: View {
    @Bindable var workspace: Workspace
    let note: Note

    var body: some View {
        Menu("Move to folder") {
            Button {
                workspace.moveNote(note.id, to: nil)
            } label: {
                Label("No folder", systemImage: note.folderID == nil ? "checkmark" : "tray")
            }
            if !workspace.notebook.library.folders.isEmpty {
                Divider()
                ForEach(workspace.notebook.library.folders.sorted {
                    workspace.notebook.library.folderPath($0.id).localizedStandardCompare(workspace.notebook.library.folderPath($1.id)) == .orderedAscending
                }) { folder in
                    Button {
                        workspace.moveNote(note.id, to: folder.id)
                    } label: {
                        Label(workspace.notebook.library.folderPath(folder.id), systemImage: note.folderID == folder.id ? "checkmark" : "folder")
                    }
                }
            }
        }
    }
}

struct MoveFolderMenu: View {
    @Bindable var workspace: Workspace
    let folder: NoteFolder

    private var destinations: [NoteFolder] {
        let subtree = workspace.notebook.library.descendantFolderIDs(folder.id)
        return workspace.notebook.library.folders.filter { !subtree.contains($0.id) }
            .sorted {
                workspace.notebook.library.folderPath($0.id).localizedStandardCompare(workspace.notebook.library.folderPath($1.id)) == .orderedAscending
            }
    }

    var body: some View {
        Menu("Move folder") {
            Button("Top level", systemImage: folder.parentID == nil ? "checkmark" : "folder") {
                workspace.moveFolder(folder.id, to: nil)
            }
            if !destinations.isEmpty {
                Divider()
                ForEach(destinations) { destination in
                    Button(workspace.notebook.library.folderPath(destination.id), systemImage: folder.parentID == destination.id ? "checkmark" : "folder") {
                        workspace.moveFolder(folder.id, to: destination.id)
                    }
                }
            }
        }
    }
}

struct TagBrowserView: View {
    @Environment(\.slipStyle) private var style
    @Bindable var workspace: Workspace

    private var tags: [String] {
        Array(Set(workspace.notebook.library.notes.filter { $0.deletedAt == nil }.flatMap(\.allTags))).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tags").font(.system(size: 12, weight: .semibold))
            if tags.isEmpty {
                Text("Add tags from a note’s footer.")
                    .font(.system(size: 11)).foregroundStyle(style.secondary)
                    .padding(.vertical, 8)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(tags, id: \.self) { tag in
                            Button {
                                workspace.query = ""
                                workspace.changeFilter(.tag(tag))
                                workspace.showTagBrowser = false
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: workspace.settings.preferences.tagIcons[tag] ?? "number")
                                        .frame(width: 14).foregroundStyle(style.secondary)
                                    Text(tag).lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .font(.system(size: 12)).foregroundStyle(style.text)
                                .padding(.horizontal, 7).frame(height: 28)
                                .background(workspace.filter == .tag(tag) ? style.rowSelection : .clear, in: RoundedRectangle(cornerRadius: 5))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Menu("Icon") {
                                    ForEach(TagIcon.allCases) { icon in
                                        Button(icon.title, systemImage: icon.symbol) {
                                            workspace.settings.preferences.tagIcons[tag] = icon.symbol
                                        }
                                    }
                                    Divider()
                                    Button("Reset") { workspace.settings.preferences.tagIcons.removeValue(forKey: tag) }
                                }
                            }
                        }
                    }
                }.frame(height: min(240, CGFloat(tags.count) * 30))
            }
        }
        .padding(14).frame(width: 220)
        .background(style.popup)
    }
}
