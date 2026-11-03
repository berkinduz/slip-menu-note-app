import SwiftUI
import SlipCore

struct SidebarView: View {
    @Environment(\.slipStyle) private var style
    @Bindable var workspace: Workspace

    private var locationSymbol: String {
        switch workspace.filter {
        case .folder: "folder"
        case .tag: "tag"
        case .pinned: "pin"
        case .trash: "trash"
        case .all: "tray"
        }
    }
    private var locationTitle: String {
        if let id = workspace.currentFolderID {
            return workspace.notebook.library.folders.first { $0.id == id }?.name ?? workspace.filterTitle
        }
        return workspace.filterTitle
    }

    var body: some View {
        VStack(spacing: 12) {
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
            .padding(.horizontal, 10).frame(height: 32)
            .background(style.input, in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 12).padding(.top, 12)

            HStack(spacing: 4) {
                Button {
                    workspace.showTagBrowser = false
                    workspace.showFolderBrowser.toggle()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: locationSymbol).frame(width: 14).foregroundStyle(style.secondary)
                        Text(locationTitle).lineLimit(1).truncationMode(.middle)
                        Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold)).foregroundStyle(style.secondary)
                        Spacer(minLength: 0)
                    }
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(style.text)
                    .padding(.leading, 8).frame(height: 30).contentShape(Rectangle())
                }
                .buttonStyle(.plain).help(workspace.filterTitle)
                .accessibilityLabel("Browse folders and notes, current: \(workspace.filterTitle)")
                .popover(isPresented: $workspace.showFolderBrowser, arrowEdge: .trailing) {
                    LibraryBrowserView(workspace: workspace)
                }
                if case .tag = workspace.filter {
                    IconButton(symbol: "xmark", label: "Clear tag filter", size: 24) { workspace.changeFilter(.all) }
                }
                IconButton(symbol: "tag", label: "Browse tags", selected: workspace.showTagBrowser) {
                    workspace.showFolderBrowser = false
                    workspace.showTagBrowser.toggle()
                }
                .popover(isPresented: $workspace.showTagBrowser, arrowEdge: .trailing) {
                    TagBrowserView(workspace: workspace)
                }
            }.padding(.horizontal, 11)

            if workspace.visibleNotes.isEmpty {
                VStack(spacing: 9) {
                    Image(systemName: workspace.filter == .trash ? "trash" : "note.text").font(.system(size: 22, weight: .light))
                    Text(workspace.filter == .trash ? "Trash is empty" : "No notes here yet").font(.system(size: 12))
                }
                .foregroundStyle(style.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(workspace.visibleNotes) { note in
                            NoteRow(note: note, selected: workspace.notebook.selectedNote?.id == note.id,
                                    showPreview: workspace.settings.preferences.showNotePreviews) { workspace.select(note) }
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
                    }.padding(.horizontal, 8).padding(.bottom, 5)
                }
            }
            HStack {
                Text("\(workspace.visibleNotes.count) \(workspace.visibleNotes.count == 1 ? "note" : "notes")")
                    .font(.system(size: 10)).foregroundStyle(style.secondary)
                Spacer()
                IconButton(symbol: "trash", label: "Trash", selected: workspace.filter == .trash, size: 24) {
                    workspace.query = ""
                    workspace.changeFilter(.trash)
                }
            }.padding(.horizontal, 16).padding(.bottom, 9)
        }
        .background(style.sidebar)
    }
}

private struct NoteRow: View {
    @Environment(\.slipStyle) private var style
    let note: Note
    let selected: Bool
    let showPreview: Bool
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 7) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(note.displayTitle).font(.system(size: 12, weight: selected ? .semibold : .medium))
                        .foregroundStyle(style.text).lineLimit(2).multilineTextAlignment(.leading)
                    if showPreview, !note.excerpt.isEmpty {
                        Text(note.excerpt).font(.system(size: 11)).foregroundStyle(style.secondary).lineLimit(1)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                if note.isPinned {
                    Image(systemName: "pin.fill").font(.system(size: 9)).foregroundStyle(style.secondary)
                        .padding(.top, 3).accessibilityLabel("Pinned")
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? style.rowSelection : (hovered ? style.hover : .clear), in: RoundedRectangle(cornerRadius: 11))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).onHover { hovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
