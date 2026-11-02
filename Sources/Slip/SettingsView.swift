import SwiftUI
import SlipCore

struct SettingsView: View {
    @Bindable var workspace: Workspace
    let pane: SettingsPane
    @Environment(\.slipStyle) private var style

    private var store: PreferencesStore { workspace.settings }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if pane == .appearance {
                AppearanceSettings(store: store)
            } else {
                WritingSettings(workspace: workspace)
            }
            Spacer(minLength: 0)
            if let error = store.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("settings error: \(error)")
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(style.sidebar)
    }
}

private struct AppearanceSettings: View {
    @Bindable var store: PreferencesStore
    @Environment(\.slipStyle) private var style

    private var fontSize: Binding<Double> {
        Binding {
            store.preferences.fontSize
        } set: { value in
            var preferences = store.preferences
            preferences.fontSize = value
            preferences.lineHeight = min(max(preferences.lineHeight, value + 2), value * 2.4)
            store.preferences = preferences
        }
    }

    private var families: [String] {
        let available = EditorTypography.families
        return available.contains(store.preferences.fontFamily) ? available : [store.preferences.fontFamily] + available
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Form {
                Picker("theme", selection: $store.preferences.theme) {
                    ForEach(AppTheme.allCases) { theme in Text(theme.title).tag(theme) }
                }
                Picker("editor font", selection: $store.preferences.fontFamily) {
                    ForEach(families, id: \.self) { family in
                        Text(family == "System" ? "sf pro text" : family == "System Monospaced" ? "system mono" : family.lowercased()).tag(family)
                    }
                }
                Stepper(value: fontSize, in: 10...28, step: 1) {
                    Text("font size: \(Int(store.preferences.fontSize)) pt")
                }
                Stepper(value: $store.preferences.lineHeight,
                        in: (store.preferences.fontSize + 2)...(store.preferences.fontSize * 2.4), step: 1) {
                    Text("line height: \(Int(store.preferences.lineHeight)) pt")
                }
                Toggle("font ligatures", isOn: $store.preferences.fontLigatures)
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text("sample").font(.caption).foregroundStyle(style.secondary)
                Text("the quick brown fox.\n0123456789")
                    .font(EditorTypography.swiftUIFont(store.preferences))
                    .lineSpacing(max(0, store.preferences.lineHeight - store.preferences.fontSize - 2))
                    .foregroundStyle(style.text)
                    .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
                    .padding(12)
                    .background(style.canvas, in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(style.line, lineWidth: 1))
            }
        }
    }
}

private struct WritingSettings: View {
    @Bindable var workspace: Workspace
    @Environment(\.slipStyle) private var style

    var body: some View {
        @Bindable var store = workspace.settings
        VStack(alignment: .leading, spacing: 16) {
            Form {
                Toggle("check spelling", isOn: $store.preferences.spellChecking)
                Toggle("continue lists", isOn: $store.preferences.continueLists)
                Toggle("slash commands", isOn: $store.preferences.slashCommands)
                Toggle("keep window open", isOn: $store.preferences.keepOpen)
                Toggle("show sidebar at launch", isOn: $store.preferences.sidebarAtLaunch)
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .fixedSize(horizontal: false, vertical: true)

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("local storage")
                    Text(workspace.notebook.directory.path)
                        .font(.caption)
                        .foregroundStyle(style.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Button("show folder") { workspace.revealStorage() }
            }
            .padding(.horizontal, 8)
            HStack {
                Text("open slip")
                Spacer()
                Text("⌃⌥N").foregroundStyle(style.secondary)
            }
            .font(.callout)
            .padding(.horizontal, 8)
        }
    }
}
