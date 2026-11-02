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
        case .tag: "tag"
        case .folder: "folder"
        case .tray: "inbox"
        case .briefcase: "work"
        case .house: "home"
        case .lightbulb: "ideas"
        case .bookmark: "bookmark"
        case .star: "star"
        case .heart: "heart"
        case .calendar: "calendar"
        case .terminal: "code"
        case .pencil: "writing"
        case .book: "reading"
        case .checkmark: "tasks"
        case .paperplane: "travel"
        case .globe: "world"
        case .music: "music"
        case .leaf: "nature"
        }
    }
}
