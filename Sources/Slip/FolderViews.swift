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
