import Foundation
import Observation

public enum AppTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case kanagawaDragon, system, light, dark, dawn, dusk, ocean, forest
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .kanagawaDragon: "Slip Theme"
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        case .dawn: "Linen"
        case .dusk: "Dusk"
        case .ocean: "Ocean"
        case .forest: "Forest"
        }
    }
}

public enum AccentColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case theme, sand, sage, blue, rose, violet
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }

    public func rgb(dark: Bool) -> UInt32? {
        switch self {
        case .theme: nil
        case .sand: dark ? 0xD6BE91 : 0x806339
        case .sage: dark ? 0xACC9AD : 0x456A4D
        case .blue: dark ? 0xA8C4E0 : 0x436A93
        case .rose: dark ? 0xDBACBA : 0x99566C
        case .violet: dark ? 0xBFB2E0 : 0x77609E
        }
    }
}

public enum NoteSort: String, Codable, CaseIterable, Identifiable, Sendable {
    case updated, created, title
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .updated: "Last edited"
        case .created: "Date created"
        case .title: "Title"
        }
    }
}

public enum NewNoteStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case blank, task, bullet
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .blank: "Blank note"
        case .task: "Checklist"
        case .bullet: "Bullet list"
        }
    }
    public var starterText: String {
        switch self {
        case .blank: ""
        case .task: "- [ ] "
        case .bullet: "- "
        }
    }
}

public struct AppPreferences: Codable, Equatable, Sendable {
    public var theme: AppTheme = .kanagawaDragon
    public var fontFamily = "System"
    public var fontSize: Double = 14
    public var lineHeight: Double = 20
    public var fontLigatures = true
    public var spellChecking = true
    public var continueLists = true
    public var slashCommands = true
    public var keepOpen = false
    public var sidebarAtLaunch = false
    public var tagIcons: [String: String] = [:]
    public var accent: AccentColor = .theme
    public var editorPadding: Double = 24
    public var paragraphSpacing: Double = 4
    public var noteSort: NoteSort = .updated
    public var newNoteStyle: NewNoteStyle = .blank
    public var showNotePreviews = true
    public var showWordCount = false
    public var showOnLaunch = true
    public var autoCorrect = false
    public var smartPunctuation = false
    public var automaticallyCheckUpdates = true
    public var lastUpdateCheck: Date?
    public var syncFolderBookmark: Data?
    public var syncFolderStateIDs: [String: String] = [:]

    public init() { }

    private enum CodingKeys: String, CodingKey {
        case theme, fontFamily, fontSize, lineHeight, fontLigatures, spellChecking
        case continueLists, slashCommands, keepOpen, sidebarAtLaunch, tagIcons
        case accent, editorPadding, paragraphSpacing, noteSort, newNoteStyle
        case showNotePreviews, showWordCount, showOnLaunch, autoCorrect, smartPunctuation
        case automaticallyCheckUpdates, lastUpdateCheck, syncFolderBookmark, syncFolderStateIDs
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        theme = try values.decode(AppTheme.self, forKey: .theme)
        fontFamily = try values.decode(String.self, forKey: .fontFamily)
        fontSize = try values.decode(Double.self, forKey: .fontSize)
        lineHeight = try values.decode(Double.self, forKey: .lineHeight)
        fontLigatures = try values.decode(Bool.self, forKey: .fontLigatures)
        spellChecking = try values.decode(Bool.self, forKey: .spellChecking)
        continueLists = try values.decode(Bool.self, forKey: .continueLists)
        slashCommands = try values.decode(Bool.self, forKey: .slashCommands)
        keepOpen = try values.decode(Bool.self, forKey: .keepOpen)
        sidebarAtLaunch = try values.decode(Bool.self, forKey: .sidebarAtLaunch)
        tagIcons = try values.decodeIfPresent([String: String].self, forKey: .tagIcons) ?? [:]
        accent = try values.decodeIfPresent(AccentColor.self, forKey: .accent) ?? .theme
        editorPadding = try values.decodeIfPresent(Double.self, forKey: .editorPadding) ?? 24
        paragraphSpacing = try values.decodeIfPresent(Double.self, forKey: .paragraphSpacing) ?? 4
        noteSort = try values.decodeIfPresent(NoteSort.self, forKey: .noteSort) ?? .updated
        newNoteStyle = try values.decodeIfPresent(NewNoteStyle.self, forKey: .newNoteStyle) ?? .blank
        showNotePreviews = try values.decodeIfPresent(Bool.self, forKey: .showNotePreviews) ?? true
        showWordCount = try values.decodeIfPresent(Bool.self, forKey: .showWordCount) ?? false
        showOnLaunch = try values.decodeIfPresent(Bool.self, forKey: .showOnLaunch) ?? true
        autoCorrect = try values.decodeIfPresent(Bool.self, forKey: .autoCorrect) ?? false
        smartPunctuation = try values.decodeIfPresent(Bool.self, forKey: .smartPunctuation) ?? false
        automaticallyCheckUpdates = try values.decodeIfPresent(Bool.self, forKey: .automaticallyCheckUpdates) ?? true
        lastUpdateCheck = try values.decodeIfPresent(Date.self, forKey: .lastUpdateCheck)
        syncFolderBookmark = try values.decodeIfPresent(Data.self, forKey: .syncFolderBookmark)
        syncFolderStateIDs = try values.decodeIfPresent([String: String].self, forKey: .syncFolderStateIDs) ?? [:]
    }
}

@MainActor @Observable
public final class PreferencesStore {
    public var preferences: AppPreferences {
        didSet { if preferences != oldValue { save() } }
    }
    public private(set) var errorMessage: String?
    public let fileURL: URL

    public init(directory: URL) {
        fileURL = directory.appendingPathComponent("preferences.json")
        preferences = AppPreferences()
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do { preferences = try JSONDecoder().decode(AppPreferences.self, from: Data(contentsOf: fileURL)) }
            catch { errorMessage = "Couldn’t read settings. Defaults are shown. \(error.localizedDescription)" }
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(preferences).write(to: fileURL, options: .atomic)
            errorMessage = nil
        } catch { errorMessage = "Couldn’t save settings. \(error.localizedDescription)" }
    }
}
