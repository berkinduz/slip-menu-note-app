import SwiftUI
import SlipCore

struct SidebarView: View {
    @Environment(\.slipStyle) private var style
    @Bindable var workspace: Workspace
    @State private var expandedFolders: Set<UUID> = []

    private func children(of parentID: UUID?) -> [NoteFolder] {
        workspace.notebook.library.folders.filter { $0.parentID == parentID }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func visibleCount(parentID: UUID? = nil) -> Int {
        children(of: parentID).reduce(0) { count, folder in
            count + 1 + (expandedFolders.contains(folder.id) ? visibleCount(parentID: folder.id) : 0)
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundStyle(style.secondary)
                SearchField(text: $workspace.query, focusRequest: workspace.searchRequest) {
                    workspace.inputFocus = .search
                    workspace.searchRequest = nil
                }
                .help("Search notes or #tags (⌘F)")
                if !workspace.query.isEmpty {
                    Button { workspace.query = "" } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 11)).foregroundStyle(style.secondary)
                    }.buttonStyle(.plain).accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 10).frame(height: 30)
            .background(style.input, in: RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 11).padding(.top, 10)

            HStack {
                Text("Folders").font(.system(size: 11, weight: .medium)).foregroundStyle(style.secondary)
                Spacer()
                IconButton(symbol: "folder.badge.plus", label: "New folder") { workspace.createFolder() }
                    .disabled(!workspace.notebook.canWrite)
            }
            .padding(.horizontal, 16).frame(height: 20)

            VStack(spacing: 1) {
                Button { workspace.query = ""; workspace.changeFilter(.all) } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "tray").frame(width: 14)
                        Text("All notes")
                        Spacer(minLength: 0)
                    }
                    .font(.system(size: 12)).foregroundStyle(style.text)
                    .padding(.leading, 23).padding(.trailing, 8).frame(height: 28)
                    .background(workspace.filter == .all ? style.rowSelection : .clear, in: RoundedRectangle(cornerRadius: 5))
                    .contentShape(Rectangle())
                }.buttonStyle(.plain)
                if !workspace.notebook.library.folders.isEmpty {
                    ScrollView {
                        VStack(spacing: 1) {
                            ForEach(children(of: nil)) { folder in
                                FolderTreeRow(folder: folder, depth: 0, expanded: $expandedFolders, workspace: workspace)
                            }
                        }
                    }.frame(height: min(168, CGFloat(visibleCount()) * 28))
                }
            }
            .padding(.horizontal, 7)
            .contextMenu { Button("New folder", systemImage: "folder.badge.plus") { workspace.createFolder() } }

            Hairline().padding(.horizontal, 14)
            Text(workspace.filter == .all ? "Notes" : workspace.filterTitle)
                .font(.system(size: 11, weight: .medium)).foregroundStyle(style.secondary)
                .lineLimit(1).truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)

            if workspace.visibleNotes.isEmpty {
                Text(workspace.filter == .trash ? "Trash is empty" : "No notes yet")
                    .font(.system(size: 12)).foregroundStyle(style.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(workspace.visibleNotes) { note in
                            NoteRow(note: note, selected: workspace.notebook.selectedNote?.id == note.id) { workspace.select(note) }
                                .contextMenu {
                                    if note.deletedAt == nil {
                                        MoveNoteMenu(workspace: workspace, note: note)
                                        Button(note.isPinned ? "Unpin note" : "Pin note", systemImage: "pin") { workspace.notebook.togglePin(note.id) }
                                        Button("Move to Trash", systemImage: "trash", role: .destructive) { workspace.trash(note.id) }
                                    } else {
                                        Button("Restore", systemImage: "arrow.uturn.backward") { workspace.restore(note.id) }
                                    }
                                }
                        }
                    }.padding(.horizontal, 7).padding(.bottom, 5)
                }
            }
            Hairline().padding(.horizontal, 14)
            Button { workspace.showTagBrowser = true } label: {
                Label("Tags", systemImage: "number")
                    .font(.system(size: 11)).foregroundStyle(style.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).frame(height: 26)
                    .padding(.horizontal, 18).contentShape(Rectangle())
            }
            .buttonStyle(.plain).padding(.bottom, 4)
            .popover(isPresented: $workspace.showTagBrowser, arrowEdge: .trailing) {
                TagBrowserView(workspace: workspace)
            }
        }
        .background(style.sidebar)
        .onChange(of: workspace.currentFolderID) { revealCurrentFolder() }
        .onChange(of: workspace.notebook.library.folders) { revealCurrentFolder() }
        .onAppear { revealCurrentFolder() }
    }

    private func revealCurrentFolder() {
        var parentID = workspace.currentFolderID.flatMap { selected in
            workspace.notebook.library.folders.first { $0.id == selected }?.parentID
        }
        while let id = parentID {
            expandedFolders.insert(id)
            parentID = workspace.notebook.library.folders.first { $0.id == id }?.parentID
        }
    }
}

private struct FolderTreeRow: View {
    @Environment(\.slipStyle) private var style
    let folder: NoteFolder
    let depth: Int
    @Binding var expanded: Set<UUID>
    @Bindable var workspace: Workspace

    private var children: [NoteFolder] {
        workspace.notebook.library.folders.filter { $0.parentID == folder.id }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 3) {
                if children.isEmpty {
                    Color.clear.frame(width: 16, height: 26)
                } else {
                    Button {
                        if expanded.contains(folder.id) { expanded.remove(folder.id) }
                        else { expanded.insert(folder.id) }
                    } label: {
                        Image(systemName: expanded.contains(folder.id) ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8, weight: .semibold)).foregroundStyle(style.secondary)
                            .frame(width: 16, height: 26).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .accessibilityLabel("\(expanded.contains(folder.id) ? "Collapse" : "Expand") \(folder.name)")
                }
                Button { workspace.query = ""; workspace.changeFilter(.folder(folder.id)) } label: {
                    HStack(spacing: 7) {
                        Image(systemName: workspace.filter == .folder(folder.id) ? "folder.fill" : "folder")
                            .frame(width: 14).foregroundStyle(style.secondary)
                        Text(folder.name).lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .font(.system(size: 12)).foregroundStyle(style.text).frame(height: 27)
                    .contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .accessibilityLabel("Open folder \(workspace.notebook.library.folderPath(folder.id))")
                    .accessibilityAddTraits(workspace.filter == .folder(folder.id) ? .isSelected : [])
            }
            .padding(.leading, 4 + CGFloat(depth) * 12).padding(.trailing, 8)
            .background(workspace.filter == .folder(folder.id) ? style.rowSelection : .clear, in: RoundedRectangle(cornerRadius: 5))
            .contextMenu {
                Button("New subfolder", systemImage: "folder.badge.plus") { workspace.createFolder(parentID: folder.id) }
                Button("Rename…", systemImage: "pencil") { workspace.renameFolder(folder) }
                MoveFolderMenu(workspace: workspace, folder: folder)
                Divider()
                Button("Remove folder…", systemImage: "folder.badge.minus", role: .destructive) { workspace.folderToRemove = folder.id }
            }
            if expanded.contains(folder.id) {
                ForEach(children) { child in
                    FolderTreeRow(folder: child, depth: depth + 1, expanded: $expanded, workspace: workspace)
                }
            }
        }
    }
}

private struct NoteRow: View {
    @Environment(\.slipStyle) private var style
    let note: Note
    let selected: Bool
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "note.text").font(.system(size: 11))
                    .foregroundStyle(style.secondary).frame(width: 14).padding(.top, 1).accessibilityHidden(true)
                Text(note.displayTitle).font(.system(size: 12, weight: selected ? .medium : .regular))
                    .foregroundStyle(style.text).lineLimit(2).multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if note.isPinned {
                    Image(systemName: "pin.fill").font(.system(size: 8)).foregroundStyle(style.secondary)
                        .padding(.top, 3).accessibilityLabel("Pinned")
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? style.rowSelection : (hovered ? style.hover : .clear), in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).onHover { hovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
