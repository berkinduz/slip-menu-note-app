import SwiftUI
import SlipCore

struct SidebarView: View {
    @Environment(\.slipStyle) private var style
    @Bindable var workspace: Workspace
    @State private var expandedTags: Set<String> = []

    private var isSearchingTags: Bool { workspace.query.trimmingCharacters(in: .whitespaces).hasPrefix("#") }
    private var matchingTags: [String] {
        let term = NoteSearchQuery(workspace.query).tags.last ?? ""
        return workspace.notebook.library.tags.filter { term.isEmpty || $0.localizedStandardContains(term) }
    }

    private func visibleTagCount(_ nodes: [TagNode]) -> Int {
        nodes.reduce(0) { count, node in
            count + 1 + (expandedTags.contains(node.id) ? visibleTagCount(node.children) : 0)
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
                .help("search notes or #tags (⌘f)")
                if !workspace.query.isEmpty {
                    Button { workspace.query = "" } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 11)).foregroundStyle(style.secondary)
                    }.buttonStyle(.plain).accessibilityLabel("clear search")
                }
            }
            .padding(.horizontal, 10).frame(height: 30)
            .background(style.input, in: RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 11).padding(.top, 12)

            if workspace.filter != .all {
                Button { workspace.query = ""; workspace.changeFilter(.all) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left").font(.system(size: 9, weight: .semibold))
                        Text(workspace.filter.title).font(.system(size: 11, weight: .medium)).lineLimit(1)
                        Spacer()
                    }.foregroundStyle(style.secondary)
                }
                .buttonStyle(.plain).padding(.horizontal, 16).help("all notes")
            }

            if !workspace.notebook.library.tagTree.isEmpty {
                        ScrollView {
                            VStack(spacing: 1) {
                                if isSearchingTags {
                                    ForEach(matchingTags, id: \.self) { tag in
                                        Button { workspace.query = ""; workspace.changeFilter(.tag(tag)) } label: {
                                            HStack(spacing: 6) {
                                                TagIconImage(tag: tag, workspace: workspace)
                                                Text(tag).foregroundStyle(style.text).lineLimit(1)
                                                Spacer(minLength: 0)
                                            }
                                            .font(.system(size: 11)).frame(height: 24)
                                            .padding(.leading, 23).contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain).accessibilityLabel("filter by \(tag)")
                                        .accessibilityAddTraits(workspace.filter == .tag(tag) ? .isSelected : [])
                                        .background(workspace.filter == .tag(tag) ? style.rowSelection : .clear, in: RoundedRectangle(cornerRadius: 5))
                                        .contextMenu { TagIconMenu(tag: tag, workspace: workspace) }
                                    }
                                } else {
                                    ForEach(workspace.notebook.library.tagTree) { node in
                                        TagTreeRow(node: node, depth: 0, expanded: $expandedTags, workspace: workspace)
                                    }
                                }
                            }.padding(.horizontal, 7)
                        }
                        .frame(height: min(150, CGFloat(isSearchingTags ? matchingTags.count : visibleTagCount(workspace.notebook.library.tagTree)) * 25))
            }

            if !workspace.notebook.library.tagTree.isEmpty {
                Hairline().padding(.horizontal, 14)
            }
            Text("notes")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(style.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 31)

            if workspace.visibleNotes.isEmpty {
                Text(workspace.filter == .trash ? "trash is empty" : "no notes")
                    .font(.system(size: 12)).foregroundStyle(style.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(workspace.visibleNotes) { note in
                            NoteRow(note: note, selected: workspace.notebook.selectedNote?.id == note.id) { workspace.select(note) }
                                .contextMenu {
                                    if note.deletedAt == nil {
                                        Button(note.isPinned ? "unpin note" : "pin note", systemImage: "pin") { workspace.notebook.togglePin(note.id) }
                                        Button("move to trash", systemImage: "trash", role: .destructive) { workspace.trash(note.id) }
                                    } else {
                                        Button("restore", systemImage: "arrow.uturn.backward") { workspace.restore(note.id) }
                                    }
                                }
                        }
                    }.padding(.horizontal, 7).padding(.bottom, 10)
                }
            }
        }
        .background(style.sidebar)
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
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "note.text")
                    .font(.system(size: 11))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(style.secondary)
                    .frame(width: 14)
                    .padding(.top, 1)
                    .accessibilityHidden(true)
                Text(note.displayTitle).font(.system(size: 12, weight: selected ? .medium : .regular))
                    .foregroundStyle(style.text).lineLimit(2).multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if note.isPinned {
                    Image(systemName: "pin.fill").font(.system(size: 8)).foregroundStyle(style.secondary)
                        .padding(.top, 3).accessibilityLabel("pinned")
                }
            }
            .padding(.leading, 23).padding(.trailing, 8).padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? style.rowSelection : (hovered ? style.hover : .clear), in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).onHover { hovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct TagTreeRow: View {
    @Environment(\.slipStyle) private var style
    let node: TagNode
    let depth: Int
    @Binding var expanded: Set<String>
    @Bindable var workspace: Workspace

    var body: some View {
        VStack(spacing: 1) {
            HStack(spacing: 3) {
                if node.children.isEmpty {
                    Color.clear.frame(width: 15, height: 22)
                } else {
                    Button {
                        if expanded.contains(node.id) { expanded.remove(node.id) }
                        else { expanded.insert(node.id) }
                    } label: {
                        Image(systemName: expanded.contains(node.id) ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(style.secondary)
                            .frame(width: 15, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(expanded.contains(node.id) ? "collapse" : "expand") \(node.id)")
                }
                Button { workspace.query = ""; workspace.changeFilter(.tag(node.id)) } label: {
                    HStack(spacing: 6) {
                        TagIconImage(tag: node.id, workspace: workspace)
                        Text(node.name).lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(style.text)
                    .frame(height: 24)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("filter by \(node.id)")
                .accessibilityAddTraits(workspace.filter == .tag(node.id) ? .isSelected : [])
            }
            .padding(.leading, CGFloat(depth) * 12 + 5)
            .padding(.trailing, 6)
            .background(workspace.filter == .tag(node.id) ? style.rowSelection : .clear, in: RoundedRectangle(cornerRadius: 5))
            .contextMenu { TagIconMenu(tag: node.id, workspace: workspace) }
            if expanded.contains(node.id) {
                ForEach(node.children) { child in
                    TagTreeRow(node: child, depth: depth + 1, expanded: $expanded, workspace: workspace)
                }
            }
        }
    }
}

private struct TagIconImage: View {
    @Environment(\.slipStyle) private var style
    let tag: String
    @Bindable var workspace: Workspace

    var body: some View {
        Image(systemName: workspace.settings.preferences.tagIcons[tag] ?? "number")
            .font(.system(size: 11))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(style.secondary)
            .frame(width: 14)
            .accessibilityHidden(true)
    }
}

private struct TagIconMenu: View {
    let tag: String
    @Bindable var workspace: Workspace

    var body: some View {
        Menu("icon") {
            ForEach(TagIcon.allCases) { icon in
                Button {
                    workspace.settings.preferences.tagIcons[tag] = icon.symbol
                } label: {
                    Label(icon.title, systemImage: icon.symbol)
                }
            }
            Divider()
            Button("reset") { workspace.settings.preferences.tagIcons.removeValue(forKey: tag) }
        }
    }
}
