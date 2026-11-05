import SwiftUI
import SlipCore

struct LibraryBrowserView: View {
    @Environment(\.slipStyle) private var style
    @Bindable var workspace: Workspace
    @State private var query = ""
    @State private var parentID: UUID?

    private var folders: [NoteFolder] {
        workspace.notebook.library.folders.filter {
            if !query.isEmpty { return workspace.notebook.library.folderPath($0.id).localizedStandardContains(query) }
            if parentID == nil, let ancestor = $0.parentID {
                return !workspace.notebook.library.folders.contains { $0.id == ancestor }
            }
            return $0.parentID == parentID
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    private var parent: NoteFolder? {
        workspace.notebook.library.folders.first { $0.id == parentID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                if let parent {
                    IconButton(symbol: "chevron.left", label: "Back to parent folder", size: 24) { parentID = parent.parentID }
                    Text(parent.name).lineLimit(1)
                } else { Text("Browse notes") }
                Spacer(minLength: 0)
                IconButton(symbol: "folder.badge.plus", label: "New folder", size: 26) {
                    workspace.showFolderBrowser = false
                    workspace.createFolder(parentID: parentID)
                }.disabled(!workspace.notebook.canWrite)
            }.font(.system(size: 14, weight: .semibold))
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass").foregroundStyle(style.secondary)
                TextField("Find a folder", text: $query).textFieldStyle(.plain)
            }.font(.system(size: 12)).padding(9).background(style.canvas, in: RoundedRectangle(cornerRadius: 10))
            if query.isEmpty {
                VStack(spacing: 2) {
                    location("All notes", symbol: "tray", filter: .all)
                    location("Pinned", symbol: "pin", filter: .pinned)
                }
                SettingsDivider().padding(.vertical, -4)
                Text(parent == nil ? "Folders" : "Subfolders").font(.system(size: 11, weight: .medium)).foregroundStyle(style.secondary).padding(.leading, 8)
            }
            if folders.isEmpty {
                Text(query.isEmpty ? "No folders here yet" : "No matching folders")
                    .font(.system(size: 12)).foregroundStyle(style.secondary).padding(.horizontal, 8).padding(.vertical, 12)
            } else {
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(folders) { folder in
                            HStack(spacing: 2) {
                                Button { select(.folder(folder.id)) } label: {
                                    HStack(spacing: 9) {
                                        Image(systemName: "folder").frame(width: 16).foregroundStyle(style.accent)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(folder.name).lineLimit(1)
                                            if !query.isEmpty, folder.parentID != nil {
                                                Text(workspace.notebook.library.folderPath(folder.id)).font(.system(size: 10)).foregroundStyle(style.secondary).lineLimit(1)
                                            }
                                        }
                                        Spacer(minLength: 0)
                                        if workspace.currentFolderID == folder.id {
                                            Image(systemName: "checkmark").font(.system(size: 10)).foregroundStyle(style.accent)
                                        }
                                    }.font(.system(size: 12)).foregroundStyle(style.text).padding(.leading, 10).frame(height: 36).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain).accessibilityLabel("Open folder \(workspace.notebook.library.folderPath(folder.id))")
                                if workspace.notebook.library.folders.contains(where: { $0.parentID == folder.id }) {
                                    IconButton(symbol: "chevron.right", label: "Browse subfolders of \(folder.name)", size: 28) { parentID = folder.id; query = "" }
                                }
                            }
                            .background(workspace.currentFolderID == folder.id ? style.popupSelection : .clear, in: RoundedRectangle(cornerRadius: 9))
                            .contextMenu {
                                Button("New subfolder", systemImage: "folder.badge.plus") {
                                    workspace.showFolderBrowser = false
                                    workspace.createFolder(parentID: folder.id)
                                }
                                Button("Rename…", systemImage: "pencil") {
                                    workspace.showFolderBrowser = false
                                    workspace.renameFolder(folder)
                                }
                                MoveFolderMenu(workspace: workspace, folder: folder)
                                Divider()
                                Button("Remove folder…", systemImage: "folder.badge.minus", role: .destructive) {
                                    workspace.showFolderBrowser = false
                                    workspace.folderToRemove = folder.id
                                }
                            }
                        }
                    }
                }.frame(height: min(280, CGFloat(folders.count) * (query.isEmpty ? 39 : 45)))
            }
        }
        .padding(16).frame(width: 280).foregroundStyle(style.text).background(style.popup)
        .onAppear {
            parentID = workspace.currentFolderID.flatMap { id in
                workspace.notebook.library.folders.first { $0.id == id }?.parentID
            }
        }
    }

    private func location(_ title: String, symbol: String, filter: NoteFilter) -> some View {
        Button { select(filter) } label: {
            HStack(spacing: 9) {
                Image(systemName: symbol).frame(width: 16).foregroundStyle(style.secondary)
                Text(title)
                Spacer()
                if workspace.filter == filter { Image(systemName: "checkmark").font(.system(size: 10)).foregroundStyle(style.accent) }
            }
            .font(.system(size: 12)).foregroundStyle(style.text).padding(.horizontal, 10).frame(height: 32)
            .background(workspace.filter == filter ? style.popupSelection : .clear, in: RoundedRectangle(cornerRadius: 9))
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
    private func select(_ filter: NoteFilter) {
        workspace.query = ""
        workspace.changeFilter(filter)
        workspace.showFolderBrowser = false
    }
}
