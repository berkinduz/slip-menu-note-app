import Foundation
import Observation

public enum AppTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case kanagawaDragon, system, light, dark
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .kanagawaDragon: "kanagawa dragon"
        case .system: "system"
        case .light: "light"
        case .dark: "dark"
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

    public init() { }

    private enum CodingKeys: String, CodingKey {
        case theme, fontFamily, fontSize, lineHeight, fontLigatures, spellChecking
        case continueLists, slashCommands, keepOpen, sidebarAtLaunch, tagIcons
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
            catch { errorMessage = "couldn’t read settings. defaults are shown. \(error.localizedDescription)" }
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(preferences).write(to: fileURL, options: .atomic)
            errorMessage = nil
        } catch { errorMessage = "couldn’t save settings. \(error.localizedDescription)" }
    }
}
