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

    @Test("Dragon preserves editor colors and uses neutral command menu surfaces")
    func exactDragonPalette() {
        let palette = ThemePalette.kanagawaDragon
        #expect(palette.canvas == 0x181616)
        #expect(palette.text == 0xC5C9C5)
        #expect(palette.input == 0x0D0C0C)
        #expect(palette.selection == 0x223249)
        #expect(palette.heading == 0x8BA4B0)
        #expect(palette.italic == 0xC4746E)
        #expect(palette.code == 0x8992A7)
        #expect(palette.link == 0x6A9589)
        #expect(palette.popup == palette.hover)
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
        let restored = try JSONDecoder().decode(AppPreferences.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(restored == original)
        #expect(restored.tagIcons.isEmpty)
    }

}
