import SwiftUI
import SlipCore

struct SlipStyle: Equatable {
    let theme: AppTheme
    static let system = SlipStyle(theme: .system)
    private var dragon: ThemePalette? { theme == .kanagawaDragon ? .kanagawaDragon : nil }

    var textColor: NSColor { dragon.map { NSColor(rgb: $0.text) } ?? .textColor }
    var secondaryColor: NSColor { dragon.map { NSColor(rgb: $0.secondaryText) } ?? .secondaryLabelColor }
    var tertiaryColor: NSColor { dragon.map { NSColor(rgb: $0.tertiaryText) } ?? .tertiaryLabelColor }
    var canvasColor: NSColor { dragon.map { NSColor(rgb: $0.canvas) } ?? .textBackgroundColor }
    var selectionColor: NSColor { dragon.map { NSColor(rgb: $0.selection) } ?? .selectedTextBackgroundColor }
    var headingColor: NSColor { dragon.map { NSColor(rgb: $0.heading) } ?? .textColor }
    var italicColor: NSColor { dragon.map { NSColor(rgb: $0.italic) } ?? .textColor }
    var codeColor: NSColor { dragon.map { NSColor(rgb: $0.code) } ?? .secondaryLabelColor }
    var highlightBackgroundColor: NSColor { dragon != nil ? NSColor(rgb: 0x4C432C) : NSColor.systemYellow.withAlphaComponent(0.25) }
    var highlightTextColor: NSColor { dragon != nil ? NSColor(rgb: 0xE6C384) : .textColor }
    var linkColor: NSColor { dragon.map { NSColor(rgb: $0.link) } ?? .linkColor }
    var sourceLinkColor: NSColor { dragon != nil ? NSColor(rgb: 0xB6927B) : .linkColor }
    var quoteColor: NSColor { dragon.map { NSColor(rgb: $0.quote) } ?? .secondaryLabelColor }
    var accentColor: NSColor {
        if let dragon { return NSColor(rgb: dragon.accent) }
        return NSColor(name: "Slip Accent") { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(srgbRed: 0.66, green: 0.68, blue: 1.0, alpha: 1)
                : NSColor(srgbRed: 0.32, green: 0.35, blue: 0.70, alpha: 1)
        }
    }

    var text: Color { Color(nsColor: textColor) }
    var secondary: Color { Color(nsColor: secondaryColor) }
    var tertiary: Color { Color(nsColor: tertiaryColor) }
    var accent: Color { Color(nsColor: accentColor) }
    var canvas: Color { Color(nsColor: canvasColor) }
    var heading: Color { Color(nsColor: headingColor) }
    var link: Color { Color(nsColor: linkColor) }
    var code: Color { Color(nsColor: codeColor) }
    var sidebar: Color { dragon.map { Color(nsColor: NSColor(rgb: $0.sidebar)) } ?? Color(nsColor: .windowBackgroundColor) }
    var input: Color { dragon.map { Color(nsColor: NSColor(rgb: $0.input)) } ?? text.opacity(0.035) }
    var line: Color { dragon.map { Color(nsColor: NSColor(rgb: $0.border)) } ?? Color(nsColor: .separatorColor).opacity(0.48) }
    var rowSelection: Color { dragon.map { Color(nsColor: NSColor(rgb: $0.rowSelection)) } ?? canvas }
    var hover: Color { dragon.map { Color(nsColor: NSColor(rgb: $0.hover)) } ?? text.opacity(0.035) }
    var popup: Color { dragon.map { Color(nsColor: NSColor(rgb: $0.popup)) } ?? sidebar }
    var popupSelection: Color { dragon.map { Color(nsColor: NSColor(rgb: $0.popupSelection)) } ?? accent.opacity(0.10) }
    var chrome: Color { dragon != nil ? Color(nsColor: NSColor(rgb: 0x393836)) : canvas }
    var footer: Color { dragon != nil ? input : canvas }

    var appearance: NSAppearance? {
        switch theme {
        case .kanagawaDragon, .dark: NSAppearance(named: .darkAqua)
        case .light: NSAppearance(named: .aqua)
        case .system: nil
        }
    }

    var colorScheme: ColorScheme? {
        switch theme {
        case .kanagawaDragon, .dark: .dark
        case .light: .light
        case .system: nil
        }
    }
}

extension NSColor {
    convenience init(rgb: UInt32) {
        self.init(srgbRed: Double((rgb >> 16) & 255) / 255, green: Double((rgb >> 8) & 255) / 255, blue: Double(rgb & 255) / 255, alpha: 1)
    }
}

extension EnvironmentValues {
    @Entry var slipStyle: SlipStyle = .system
    @Entry var editorPreferences = AppPreferences()
}

struct ThemedRoot<Content: View>: View {
    @Bindable var settings: PreferencesStore
    let content: Content

    var body: some View {
        let style = SlipStyle(theme: settings.preferences.theme)
        content
            .environment(\.slipStyle, style)
            .environment(\.editorPreferences, settings.preferences)
            .foregroundStyle(style.text)
            .tint(style.accent)
            .preferredColorScheme(style.colorScheme)
    }
}

@MainActor enum EditorTypography {
    static let families: [String] = {
        ["System", "System Monospaced"] + NSFontManager.shared.availableFontFamilies.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }()

    static func font(_ preferences: AppPreferences, size: Double? = nil) -> NSFont {
        let size = size ?? preferences.fontSize
        if preferences.fontFamily == "System" { return .systemFont(ofSize: size) }
        if preferences.fontFamily != "System Monospaced" {
            if let font = NSFontManager.shared.font(withFamily: preferences.fontFamily, traits: [], weight: 5, size: size)
                ?? NSFont(name: preferences.fontFamily, size: size) { return font }
        }
        return .monospacedSystemFont(ofSize: size, weight: .regular)
    }

    static func swiftUIFont(_ preferences: AppPreferences, size: Double? = nil) -> Font {
        let font = font(preferences, size: size)
        return .custom(font.fontName, fixedSize: font.pointSize)
    }
}

struct SlipMark: View {
    @Environment(\.slipStyle) private var style
    var size: CGFloat = 25
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.27).fill(style.accent.opacity(0.12))
            Image(nsImage: SlipMarkImage.image())
                .resizable().scaledToFit().frame(width: size * 0.64, height: size * 0.64)
                .foregroundStyle(style.accent)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct IconButton: View {
    @Environment(\.slipStyle) private var style
    let symbol: String
    let label: String
    var selected = false
    var size: CGFloat = 28
    var action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(selected ? style.accent : style.secondary)
                .frame(width: size, height: size)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selected ? style.accent.opacity(0.12) : style.text.opacity(hovered ? 0.055 : 0))
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}

struct TagPill: View {
    @Environment(\.slipStyle) private var style
    let tag: String
    var small = false

    var body: some View {
        HStack(spacing: 3) {
            Text("#").foregroundStyle(style.accent.opacity(0.7))
            Text(tag).lineLimit(1)
        }
        .font(.system(size: small ? 10 : 11, weight: .medium))
        .foregroundStyle(style.accent)
        .padding(.horizontal, small ? 5 : 7)
        .padding(.vertical, small ? 2 : 4)
        .background(style.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
    }
}

struct KeyCap: View {
    @Environment(\.slipStyle) private var style
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(style.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(style.text.opacity(0.04), in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(style.line, lineWidth: 0.5))
    }
}

struct Hairline: View {
    @Environment(\.slipStyle) private var style
    var body: some View { Rectangle().fill(style.line).frame(height: 0.5) }
}
