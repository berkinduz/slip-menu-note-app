import SwiftUI
import SlipCore

struct SettingsView: View {
    @Bindable var workspace: Workspace
    var onPaneChange: (SettingsPane) -> Void
    @Environment(\.slipStyle) private var style
    private var pane: SettingsPane { workspace.settingsPane }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 9) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable().frame(width: 30, height: 30).accessibilityHidden(true)
                    Text("Slip").font(.system(size: 18, weight: .semibold)).tracking(-0.4)
                }.padding(.horizontal, 16)
                VStack(spacing: 4) {
                    ForEach(SettingsPane.allCases) { item in
                        Button { workspace.settingsPane = item } label: {
                            HStack(spacing: 10) {
                                Image(systemName: item.symbol).font(.system(size: 14)).frame(width: 20)
                                Text(item.title).font(.system(size: 12, weight: pane == item ? .medium : .regular))
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(pane == item ? style.text : style.secondary)
                            .padding(.horizontal, 12).frame(height: 38)
                            .background(pane == item ? style.accent.opacity(0.13) : .clear, in: RoundedRectangle(cornerRadius: 10))
                            .contentShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(pane == item ? .isSelected : [])
                    }
                }.padding(.horizontal, 10)
                Spacer()
                Text("A little room to think.")
                    .font(.system(size: 10)).foregroundStyle(style.secondary)
                    .padding(.horizontal, 20).padding(.bottom, 22)
            }
            .padding(.top, 52).frame(width: 170)
            .background(style.sidebar)
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text(pane.title).font(.system(size: 24, weight: .semibold)).tracking(-0.6)
                        switch pane {
                        case .appearance: AppearanceSettings(store: workspace.settings)
                        case .editor: EditorSettings(store: workspace.settings)
                        case .capture: CaptureSettings(workspace: workspace)
                        case .organization: OrganizationSettings(workspace: workspace)
                        case .data: DataSettings(workspace: workspace)
                        case .about: AboutSettings(updates: workspace.updates, settings: workspace.settings)
                        }
                        if let error = workspace.settings.errorMessage {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .font(.callout).foregroundStyle(.red)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28).padding(.top, 48).padding(.bottom, 28)
                }
                if pane == .editor {
                    SettingsPreview().padding(.horizontal, 28).padding(.top, 12).padding(.bottom, 24)
                }
            }
            .background(style.canvas)
        }
        .background(style.canvas).ignoresSafeArea()
        .onChange(of: pane) { onPaneChange(pane) }
    }
}

private struct AppearanceSettings: View {
    @Bindable var store: PreferencesStore
    @Environment(\.slipStyle) private var style

    var body: some View {
        VStack(spacing: 20) {
            SettingsSection("Theme") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 14) {
                    ForEach(AppTheme.allCases) { theme in
                        ThemeChoice(theme: theme, selected: store.preferences.theme == theme) {
                            store.preferences.theme = theme
                        }
                    }
                }
            }
            SettingsSection("Accent color") {
                HStack(spacing: 14) {
                    ForEach(AccentColor.allCases) { color in
                        AccentChoice(choice: color, selected: store.preferences.accent == color) {
                            store.preferences.accent = color
                        }
                    }
                    Spacer(minLength: 0)
                    Text(store.preferences.accent.title).font(.system(size: 12)).foregroundStyle(style.secondary)
                }
            }
            SettingsPreview()
        }
    }
}

private struct EditorSettings: View {
    @Bindable var store: PreferencesStore

    private var fontSize: Binding<Double> {
        Binding(get: { store.preferences.fontSize }, set: { value in
            store.preferences.fontSize = value
            store.preferences.lineHeight = min(max(store.preferences.lineHeight, value + 2), value * 2.4)
        })
    }
    private var families: [String] {
        let available = EditorTypography.families
        return available.contains(store.preferences.fontFamily) ? available : [store.preferences.fontFamily] + available
    }

    var body: some View {
        VStack(spacing: 20) {
            SettingsSection("Typography") {
                SettingsRow("Font") {
                    Picker("Font", selection: $store.preferences.fontFamily) {
                        ForEach(families, id: \.self) { family in
                            Text(family == "System" ? "SF Pro Text" : family == "System Monospaced" ? "SF Mono" : family).tag(family)
                        }
                    }.labelsHidden().frame(width: 210)
                }
                SettingsDivider()
                SettingsSlider("Font size", value: fontSize, range: 10...28, suffix: "pt")
                SettingsDivider()
                SettingsSlider("Line height", value: $store.preferences.lineHeight,
                               range: (store.preferences.fontSize + 2)...(store.preferences.fontSize * 2.4), suffix: "pt")
                SettingsDivider()
                SettingsToggle("Font ligatures", detail: "Combine supported character pairs.", value: $store.preferences.fontLigatures)
            }
            SettingsSection("Spacing") {
                SettingsSlider("Paragraph spacing", value: $store.preferences.paragraphSpacing, range: 0...12, suffix: "pt")
                SettingsDivider()
                SettingsRow("Page margins") {
                    Picker("Page margins", selection: $store.preferences.editorPadding) {
                        Text("Compact").tag(16.0)
                        Text("Comfortable").tag(24.0)
                        Text("Roomy").tag(32.0)
                    }.pickerStyle(.segmented).labelsHidden().frame(width: 260)
                }
            }
            SettingsSection("Writing assistance") {
                SettingsToggle("Check spelling", value: $store.preferences.spellChecking)
                SettingsDivider()
                SettingsToggle("Correct spelling automatically", value: $store.preferences.autoCorrect)
                SettingsDivider()
                SettingsToggle("Smart punctuation", detail: "Use curly quotes and typographic dashes.", value: $store.preferences.smartPunctuation)
            }
        }
    }
}

private struct CaptureSettings: View {
    @Bindable var workspace: Workspace

    var body: some View {
        @Bindable var store = workspace.settings
        VStack(spacing: 20) {
            SettingsSection("Ready when you are") {
                SettingsToggle("Launch at login", detail: "Keep Slip ready in the menu bar when you log in.", value: Binding(get: { workspace.loginItem.isEnabled }, set: { workspace.loginItem.setEnabled($0) }))
                if workspace.loginItem.requiresApproval {
                    SettingsRow("Allow Slip in Login Items", detail: "macOS needs your approval to start Slip at login.") {
                        Button("Open System Settings") { workspace.loginItem.openSystemSettings() }
                    }
                }
                if let error = workspace.loginItem.errorMessage {
                    Text(error).font(.callout).foregroundStyle(.orange)
                }
                SettingsDivider()
                SettingsRow("Open or hide Slip") { KeyCap(text: "⌃⌥N") }
                SettingsDivider()
                SettingsToggle("Show panel on launch", value: $store.preferences.showOnLaunch)
                SettingsDivider()
                SettingsToggle("Keep panel open", detail: "Keep your note visible when switching apps.", value: $store.preferences.keepOpen)
            }
            SettingsSection("Start writing") {
                SettingsRow("New notes start with") {
                    Picker("New notes start with", selection: $store.preferences.newNoteStyle) {
                        ForEach(NewNoteStyle.allCases) { item in Text(item.title).tag(item) }
                    }.pickerStyle(.segmented).labelsHidden().frame(width: 300)
                }
                SettingsDivider()
                SettingsToggle("Continue lists", detail: "Return adds the next bullet or task.", value: $store.preferences.continueLists)
                SettingsDivider()
                SettingsToggle("Slash commands", detail: "Type / for headings, tasks and more.", value: $store.preferences.slashCommands)
            }
            if !workspace.hotKeyAvailable {
                Label("⌃⌥N is in use by another app. The menu bar icon is always available.", systemImage: "keyboard")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .onAppear { workspace.loginItem.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in workspace.loginItem.refresh() }
    }
}

private struct OrganizationSettings: View {
    @Bindable var workspace: Workspace
    @Environment(\.slipStyle) private var style

    var body: some View {
        @Bindable var store = workspace.settings
        VStack(spacing: 20) {
            SettingsSection("Your note list") {
                SettingsRow("Sort notes by") {
                    Picker("Sort notes by", selection: $store.preferences.noteSort) {
                        ForEach(NoteSort.allCases) { sort in Text(sort.title).tag(sort) }
                    }.pickerStyle(.segmented).labelsHidden().frame(width: 300)
                }
                SettingsDivider()
                SettingsToggle("Show note previews", detail: "A short excerpt below each note title.", value: $store.preferences.showNotePreviews)
                SettingsDivider()
                SettingsToggle("Show word count", detail: "A quiet count in the note footer.", value: $store.preferences.showWordCount)
            }
            SettingsSection("On this Mac") {
                SettingsRow("Local storage", detail: "Notes save automatically. No account required.") {
                    Button("Show folder") { workspace.revealStorage() }.controlSize(.regular)
                }
                Text(workspace.notebook.directory.path)
                    .font(.system(size: 11)).foregroundStyle(style.secondary)
                    .textSelection(.enabled).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
            }
        }
    }
}
