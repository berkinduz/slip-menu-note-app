import Foundation
import Testing
@testable import SlipCore

@Suite("Settings")
@MainActor
struct PreferencesTests {
    @Test("First launch uses the default appearance")
    func initialAppearance() {
        let settings = AppPreferences()
        #expect(settings.theme == .kanagawaDragon)
        #expect(settings.fontFamily == "System")
        #expect(settings.fontSize == 14)
        #expect(settings.lineHeight == 20)
        #expect(settings.fontLigatures)
        #expect(settings.slashCommands)
        #expect(settings.continueLists)
    }

    @Test("Changes persist across restarts independently of note data")
    func persistence() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PreferencesStore(directory: directory)
        store.preferences.fontFamily = "Menlo"
        store.preferences.fontSize = 18
        store.preferences.lineHeight = 27
        store.preferences.theme = .light
        store.preferences.spellChecking = false
        store.preferences.continueLists = false
        store.preferences.slashCommands = false
        store.preferences.keepOpen = true
        store.preferences.sidebarAtLaunch = true
        store.preferences.accent = .rose
        store.preferences.editorPadding = 32
        store.preferences.paragraphSpacing = 8
        store.preferences.noteSort = .title
        store.preferences.newNoteStyle = .task
        store.preferences.showNotePreviews = false
        store.preferences.showWordCount = true
        store.preferences.showOnLaunch = false
        store.preferences.autoCorrect = true
        store.preferences.smartPunctuation = true
        let reopened = PreferencesStore(directory: directory)
        #expect(reopened.preferences == store.preferences)
        #expect(reopened.errorMessage == nil)
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("library.json").path))
    }

    @Test("Opening settings preserves an unreadable preferences file and reports it")
    func badPreferences() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("preferences.json")
        let original = Data("unreadable preferences".utf8)
        try original.write(to: file)
        let store = PreferencesStore(directory: directory)
        #expect(store.errorMessage != nil)
        #expect(store.preferences.theme == .kanagawaDragon)
        #expect(try Data(contentsOf: file) == original)
    }

    @Test("Theme text stays readable on editor and control surfaces", arguments: AppTheme.allCases)
    func paletteContrast(theme: AppTheme) {
        guard let palette = theme.palette else { return }
        for foreground in [palette.text, palette.secondaryText, palette.tertiaryText] {
            for background in [palette.canvas, palette.sidebar, palette.input] {
                #expect(contrast(foreground, background) >= 4.5, "\(theme.title) text contrast")
            }
        }
        for foreground in [palette.link, palette.code, palette.italic] {
            #expect(contrast(foreground, palette.canvas) >= 4.5, "\(theme.title) formatted text contrast")
        }
        #expect(contrast(palette.highlightText, palette.highlightBackground) >= 4.5)
        #expect(palette.popupSelection == palette.rowSelection)
    }
    @Test("Tag icons survive a settings restart")
    func tagIconsPersist() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PreferencesStore(directory: directory)
        store.preferences.tagIcons["work/ideas"] = TagIcon.lightbulb.symbol
        let reopened = PreferencesStore(directory: directory)
        #expect(reopened.preferences.tagIcons == ["work/ideas": "lightbulb"])
    }

    @Test("Existing settings without tag icons preserve all values")
    func oldSettingsDecode() throws {
        var original = AppPreferences()
        original.fontSize = 22
        original.theme = .light
        let data = try JSONEncoder().encode(original)
        var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json.removeValue(forKey: "tagIcons")
        for key in ["accent", "editorPadding", "paragraphSpacing", "noteSort", "newNoteStyle", "showNotePreviews", "showWordCount", "showOnLaunch", "autoCorrect", "smartPunctuation"] {
            json.removeValue(forKey: key)
        }
        let restored = try JSONDecoder().decode(AppPreferences.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(restored == original)
        #expect(restored.tagIcons.isEmpty)
    }

    private func contrast(_ first: UInt32, _ second: UInt32) -> Double {
        func luminance(_ rgb: UInt32) -> Double {
            let channels = [16, 8, 0].map { shift -> Double in
                let value = Double((rgb >> shift) & 255) / 255
                return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return channels[0] * 0.2126 + channels[1] * 0.7152 + channels[2] * 0.0722
        }
        let a = luminance(first), b = luminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

}
