import Foundation

/// A curated set of monochrome SF Symbols for organizing tags.
public enum TagIcon: String, CaseIterable, Identifiable, Sendable {
    case tag, folder, tray, briefcase, house, lightbulb, bookmark, star, heart, calendar, terminal, pencil
    case book = "book.closed"
    case checkmark = "checkmark.circle"
    case paperplane, globe, music = "music.note", leaf

    public var id: String { rawValue }
    public var symbol: String { rawValue }
    public var title: String {
        switch self {
        case .tag: "Tag"
        case .folder: "Folder"
        case .tray: "Inbox"
        case .briefcase: "Work"
        case .house: "Home"
        case .lightbulb: "Ideas"
        case .bookmark: "Bookmark"
        case .star: "Star"
        case .heart: "Heart"
        case .calendar: "Calendar"
        case .terminal: "Code"
        case .pencil: "Writing"
        case .book: "Reading"
        case .checkmark: "Tasks"
        case .paperplane: "Travel"
        case .globe: "World"
        case .music: "Music"
        case .leaf: "Nature"
        }
    }
}
