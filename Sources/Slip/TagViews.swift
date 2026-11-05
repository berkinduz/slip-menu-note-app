import SwiftUI
import SlipCore

struct TagEditorView: View {
    @Environment(\.slipStyle) private var style
    @Bindable var workspace: Workspace
    let noteID: UUID
    @State private var draft = ""
    @State private var focusRequest = UUID()
    @State private var highlighted = 0

    private var note: Note? { workspace.notebook.library.notes.first { $0.id == noteID } }
    private var suggestions: [TagSuggestion] {
        workspace.notebook.library.tagSuggestions(for: draft, excluding: note?.tags ?? [])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Tags").font(.system(size: 14, weight: .semibold))
                Spacer()
                IconButton(symbol: "xmark", label: "Close tags", size: 24) { workspace.showTags = false }
            }
            if let note, !note.tags.isEmpty {
                TagTokenList(tags: note.tags) { tag in
                    workspace.notebook.updateNote(noteID, tags: note.tags.filter { $0 != tag })
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "tag").font(.system(size: 12)).foregroundStyle(style.secondary)
                TagInput(text: $draft, focusRequest: focusRequest, onMove: moveSelection, onSubmit: submit,
                         onCancel: { workspace.showTags = false })
                    .frame(height: 20)
            }
            .padding(10).background(style.canvas, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(style.line, lineWidth: 0.5))
            if !suggestions.isEmpty {
                VStack(spacing: 3) {
                    ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, choice in
                        Button { add(choice) } label: {
                            HStack(spacing: 9) {
                                Image(systemName: choice.isNew ? "plus.circle" : "tag").frame(width: 15)
                                Text(choice.isNew ? "Create “\(choice.name)”" : choice.name).lineLimit(1)
                                Spacer(minLength: 0)
                                if index == highlighted { Image(systemName: "return").font(.system(size: 10)) }
                            }
                            .font(.system(size: 12)).foregroundStyle(style.text)
                            .padding(.horizontal, 9).frame(height: 32)
                            .background(index == highlighted ? style.popupSelection : .clear, in: RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).onHover { if $0 { highlighted = index } }
                        .accessibilityLabel(choice.isNew ? "Create tag \(choice.name)" : "Add tag \(choice.name)")
                    }
                }
                HStack {
                    Text("↑↓ Choose").font(.system(size: 10))
                    Spacer()
                    Text("↵ Add tag").font(.system(size: 10))
                }.foregroundStyle(style.secondary).padding(.horizontal, 3)
            } else {
                Text(draft.isEmpty ? "Type a name to create a tag." : "Already added to this note.")
                    .font(.system(size: 11)).foregroundStyle(style.secondary).padding(.horizontal, 3)
            }
        }
        .padding(16).frame(width: 310)
        .foregroundStyle(style.text).background(style.popup)
        .onChange(of: draft) { highlighted = 0 }
        .onChange(of: suggestions) { highlighted = 0 }
    }

    private func moveSelection(_ delta: Int) {
        guard !suggestions.isEmpty else { return }
        highlighted = (highlighted + delta + suggestions.count) % suggestions.count
    }
    private func submit() {
        if let choice = suggestions.dropFirst(highlighted).first { add(choice) }
    }
    private func add(_ choice: TagSuggestion) {
        guard let note else { return }
        workspace.notebook.updateNote(noteID, tags: note.tags + [choice.name])
        draft = ""
        highlighted = 0
        focusRequest = UUID()
    }
}

private struct TagTokenList: View {
    @Environment(\.slipStyle) private var style
    let tags: [String]
    let remove: (String) -> Void
    @State private var contentHeight: CGFloat = 28

    var body: some View {
        ScrollView {
            TagFlowLayout(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    HStack(spacing: 5) {
                        Text(tag).font(.system(size: 11)).lineLimit(1).help(tag)
                        Button { remove(tag) } label: {
                            Image(systemName: "xmark").font(.system(size: 8, weight: .semibold)).frame(width: 18, height: 18)
                        }.buttonStyle(.plain).accessibilityLabel("Remove \(tag) from note")
                    }
                    .foregroundStyle(style.text).padding(.leading, 9).padding(.trailing, 3).padding(.vertical, 3)
                    .background(style.accent.opacity(0.12), in: Capsule())
                }
            }
            .background(GeometryReader { geometry in Color.clear.preference(key: TagHeightKey.self, value: geometry.size.height) })
        }
        .frame(height: min(contentHeight, 112))
        .onPreferenceChange(TagHeightKey.self) { contentHeight = $0 }
    }
}

private struct TagHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 28
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct TagFlowLayout: Layout {
    let spacing: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(subviews, width: proposal.width ?? 280).0
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let (_, positions) = arrange(subviews, width: bounds.width)
        for (view, placement) in zip(subviews, positions) {
            view.place(at: CGPoint(x: bounds.minX + placement.0.x, y: bounds.minY + placement.0.y),
                       proposal: ProposedViewSize(placement.1))
        }
    }
    private func arrange(_ subviews: Subviews, width: CGFloat) -> (CGSize, [(CGPoint, CGSize)]) {
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        var positions: [(CGPoint, CGSize)] = []
        for view in subviews {
            let size = view.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if x > 0, x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            positions.append((CGPoint(x: x, y: y), size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: width, height: y + rowHeight), positions)
    }
}

struct TagBrowserView: View {
    @Environment(\.slipStyle) private var style
    @Bindable var workspace: Workspace
    @State private var query = ""
    @State private var editing: String?

    private var tags: [String] {
        workspace.notebook.library.assignedTags.filter { query.isEmpty || $0.localizedStandardContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let editing {
                TagDetailsView(workspace: workspace, tag: editing) { self.editing = nil }
            } else {
                HStack {
                    Text("Tags").font(.system(size: 14, weight: .semibold))
                    Spacer()
                    IconButton(symbol: "xmark", label: "Close tag browser", size: 24) { workspace.showTagBrowser = false }
                }
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass").foregroundStyle(style.secondary)
                    TextField("Find a tag", text: $query).textFieldStyle(.plain)
                }.font(.system(size: 12)).padding(9).background(style.canvas, in: RoundedRectangle(cornerRadius: 10))
                if tags.isEmpty {
                    Text(query.isEmpty ? "Tags you add to notes appear here." : "No matching tags")
                        .font(.system(size: 12)).foregroundStyle(style.secondary).padding(.vertical, 14)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 3) {
                            ForEach(tags, id: \.self) { tag in
                                HStack(spacing: 5) {
                                    Button {
                                        workspace.query = ""
                                        workspace.changeFilter(.tag(tag))
                                        workspace.showTagBrowser = false
                                    } label: {
                                        HStack(spacing: 9) {
                                            Image(systemName: workspace.settings.preferences.tagIcons[tag] ?? "tag")
                                                .frame(width: 16).foregroundStyle(style.accent)
                                            Text(tag).lineLimit(1)
                                            Spacer(minLength: 0)
                                            Text("\(workspace.notebook.library.filtered(by: .tag(tag)).count)")
                                                .font(.system(size: 11)).foregroundStyle(style.secondary)
                                        }
                                        .font(.system(size: 12)).foregroundStyle(style.text).frame(height: 34).contentShape(Rectangle())
                                    }.buttonStyle(.plain).accessibilityLabel("Show notes tagged \(tag)")
                                    IconButton(symbol: "slider.horizontal.3", label: "Edit \(tag) tag", size: 26) { editing = tag }
                                }
                                .padding(.leading, 10).padding(.trailing, 4)
                                .background(workspace.filter == .tag(tag) ? style.popupSelection : .clear, in: RoundedRectangle(cornerRadius: 9))
                            }
                        }
                    }.frame(height: min(280, CGFloat(tags.count) * 37))
                }
            }
        }
        .padding(16).frame(width: 290).foregroundStyle(style.text).background(style.popup)
    }
}

private struct TagDetailsView: View {
    @Environment(\.slipStyle) private var style
    @Bindable var workspace: Workspace
    let tag: String
    let onDone: () -> Void
    @State private var name: String
    @State private var icon: String?
    @State private var iconChanged = false
    @State private var confirmRemoval = false
    @State private var focusRequest = UUID()

    init(workspace: Workspace, tag: String, onDone: @escaping () -> Void) {
        self.workspace = workspace
        self.tag = tag
        self.onDone = onDone
        _name = State(initialValue: tag)
        _icon = State(initialValue: workspace.settings.preferences.tagIcons[tag])
    }
    private var normalizedName: String { Note.normalizedTags([name]).first ?? "" }
    private var isMerge: Bool {
        normalizedName != tag && workspace.notebook.library.assignedTags.contains(normalizedName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                IconButton(symbol: "chevron.left", label: "Back to tags", size: 24, action: onDone)
                Text("Edit tag").font(.system(size: 14, weight: .semibold))
                Spacer()
            }
            VStack(alignment: .leading, spacing: 7) {
                Text("Name").font(.system(size: 11, weight: .medium)).foregroundStyle(style.secondary)
                TagInput(text: $name, focusRequest: focusRequest, placeholder: "Tag name", onSubmit: save, onCancel: onDone)
                    .frame(height: 20)
                    .padding(11).background(style.canvas, in: RoundedRectangle(cornerRadius: 10))
                if isMerge {
                    Text("Merge with the existing “\(normalizedName)” tag.")
                        .font(.system(size: 11)).foregroundStyle(style.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("Icon").font(.system(size: 11, weight: .medium)).foregroundStyle(style.secondary)
                    Spacer()
                    Button("Reset") { icon = nil; iconChanged = true }
                        .font(.system(size: 10)).buttonStyle(.plain).foregroundStyle(style.secondary)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 6), spacing: 5) {
                    ForEach(TagIcon.allCases) { choice in
                        Button { icon = choice.symbol; iconChanged = true } label: {
                            Image(systemName: choice.symbol).font(.system(size: 14)).frame(maxWidth: .infinity).frame(height: 32)
                                .foregroundStyle(icon == choice.symbol ? style.text : style.secondary)
                                .background(icon == choice.symbol ? style.accent.opacity(0.15) : style.canvas.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain).help(choice.title).accessibilityLabel("\(choice.title) tag icon")
                            .accessibilityAddTraits(icon == choice.symbol ? .isSelected : [])
                            .accessibilityRemoveTraits(icon == choice.symbol ? [] : .isSelected)
                    }
                }
            }
            HStack {
                Button("Remove tag…", role: .destructive) { confirmRemoval = true }
                    .buttonStyle(.plain).font(.system(size: 11))
                Spacer()
                Button(isMerge ? "Merge" : "Save", action: save)
                    .disabled(normalizedName.isEmpty || (normalizedName == tag && !iconChanged))
            }.padding(.top, 3)
        }
        .alert("Remove this tag?", isPresented: $confirmRemoval) {
            Button("Cancel", role: .cancel) { }
            Button("Remove tag", role: .destructive) { workspace.removeTag(tag); onDone() }
        } message: { Text("“\(tag)” will be removed from all notes. Your notes will be kept.") }
    }

    private func save() {
        guard !normalizedName.isEmpty else { return }
        workspace.renameTag(tag, to: normalizedName)
        if iconChanged { workspace.settings.preferences.tagIcons[normalizedName] = icon }
        onDone()
    }
}

struct NoteFooter: View {
    @Environment(\.slipStyle) private var style
    @Environment(\.editorPreferences) private var preferences
    @Bindable var workspace: Workspace
    let note: Note

    var body: some View {
        HStack(spacing: 6) {
            if note.allTags.isEmpty {
                Button { workspace.showTags = true } label: {
                    Label("Add tag", systemImage: "tag").font(.system(size: 11)).foregroundStyle(style.secondary)
                        .frame(height: 28).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel("Add tags")
            } else {
                ForEach(Array(note.allTags.prefix(2)), id: \.self) { tag in
                    Button { workspace.showTags = true } label: { TagPill(tag: tag) }
                        .buttonStyle(.plain).help(tag).accessibilityLabel("Edit tags: \(tag)")
                        .contextMenu {
                            Button("Find notes with this tag", systemImage: "magnifyingglass") {
                                workspace.query = ""
                                workspace.changeFilter(.tag(tag))
                                if !workspace.sidebarVisible { workspace.toggleSidebar() }
                            }
                            Button("Remove from note", systemImage: "xmark") {
                                workspace.notebook.updateNote(note.id, tags: note.tags.filter { $0 != tag })
                            }
                        }
                }
                if note.allTags.count > 2 {
                    Button("+\(note.allTags.count - 2)") { workspace.showTags = true }
                        .buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(style.secondary)
                        .accessibilityLabel("Show all \(note.allTags.count) tags")
                }
                IconButton(symbol: "plus", label: "Add or edit tags", size: 24) { workspace.showTags = true }
            }
            Spacer(minLength: 4)
            Label(workspace.notebook.saveState == .failed ? "Not saved" : (workspace.notebook.saveState == .saving ? "Saving on this Mac" : "Saved on this Mac"), systemImage: workspace.notebook.saveState == .failed ? "exclamationmark.circle" : (workspace.notebook.saveState == .saving ? "ellipsis.circle" : "checkmark.circle"))
                .labelStyle(.iconOnly).font(.system(size: 10)).foregroundStyle(style.secondary)
                .help(workspace.notebook.saveState == .failed ? "Not saved" : (workspace.notebook.saveState == .saving ? "Saving on this Mac" : "Saved on this Mac"))
            if workspace.sync.folder != nil || workspace.sync.errorMessage != nil {
                Button { workspace.showDataSettings() } label: {
                    Image(systemName: workspace.sync.errorMessage == nil ? "icloud" : "icloud.slash")
                        .font(.system(size: 11)).foregroundStyle(workspace.sync.errorMessage == nil ? style.secondary : .orange)
                        .frame(width: 24, height: 24)
                }.buttonStyle(.plain).help(workspace.sync.status).accessibilityLabel(workspace.sync.status)
            }
            if preferences.showWordCount {
                Text("\(note.wordCount) \(note.wordCount == 1 ? "word" : "words")").font(.system(size: 10)).foregroundStyle(style.secondary).lineLimit(1)
            }
        }
        .disabled(note.deletedAt != nil)
        .padding(.horizontal, preferences.editorPadding).frame(height: 36)
        .overlay(alignment: .top) { Hairline().opacity(0.55).padding(.horizontal, preferences.editorPadding) }
        .popover(isPresented: $workspace.showTags, arrowEdge: .bottom) {
            TagEditorView(workspace: workspace, noteID: note.id)
        }
    }
}
