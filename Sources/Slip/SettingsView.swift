import SwiftUI
import SlipCore

struct SettingsView: View {
    @Bindable var workspace: Workspace
    let pane: SettingsPane
    @Environment(\.slipStyle) private var style

    private var store: PreferencesStore { workspace.settings }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch pane {
            case .appearance:
                AppearanceSettings(store: store)
            case .writing:
                WritingSettings(workspace: workspace)
            case .about:
                AboutSettings()
            }
            Spacer(minLength: 0)
            if let error = store.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Settings error: \(error)")
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
                Picker("Theme", selection: $store.preferences.theme) {
                    ForEach(AppTheme.allCases) { theme in Text(theme.title).tag(theme) }
                }
                Picker("Editor Font", selection: $store.preferences.fontFamily) {
                    ForEach(families, id: \.self) { family in
                        Text(family == "System" ? "SF Pro Text" : family).tag(family)
                    }
                }
                Stepper(value: fontSize, in: 10...28, step: 1) {
                    Text("Font Size: \(Int(store.preferences.fontSize)) pt")
                }
                Stepper(value: $store.preferences.lineHeight,
                        in: (store.preferences.fontSize + 2)...(store.preferences.fontSize * 2.4), step: 1) {
                    Text("Line Height: \(Int(store.preferences.lineHeight)) pt")
                }
                Toggle("Font Ligatures", isOn: $store.preferences.fontLigatures)
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text("Sample").font(.caption).foregroundStyle(style.secondary)
                Text("The quick brown fox.\n0123456789")
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
                Toggle("Check Spelling", isOn: $store.preferences.spellChecking)
                Toggle("Continue Lists", isOn: $store.preferences.continueLists)
                Toggle("Slash Commands", isOn: $store.preferences.slashCommands)
                Toggle("Keep Window Open", isOn: $store.preferences.keepOpen)
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .fixedSize(horizontal: false, vertical: true)

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Local Storage")
                    Text(workspace.notebook.directory.path)
                        .font(.caption)
                        .foregroundStyle(style.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Button("Show Folder") { workspace.revealStorage() }
            }
            .padding(.horizontal, 8)
            HStack {
                Text("Open Slip")
                Spacer()
                Text("⌃⌥N").foregroundStyle(style.secondary)
            }
            .font(.callout)
            .padding(.horizontal, 8)
        }
    }
}
