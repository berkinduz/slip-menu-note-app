// Slip Theme derives from Kanagawa Dragon by Pierre-Alain Castella (MIT).
// See THIRD-PARTY-NOTICES.txt for the original attribution.
public struct ThemePalette: Equatable, Sendable {
    public let isDark: Bool
    public let canvas: UInt32
    public let text: UInt32
    public let sidebar: UInt32
    public let input: UInt32
    public let border: UInt32
    public let secondaryText: UInt32
    public let tertiaryText: UInt32
    public let accent: UInt32
    public let selection: UInt32
    public let rowSelection: UInt32
    public let hover: UInt32
    public let heading: UInt32
    public let italic: UInt32
    public let code: UInt32
    public let link: UInt32
    public let quote: UInt32
    public let highlightBackground: UInt32
    public let highlightText: UInt32
    public var popup: UInt32 { input }
    public var popupSelection: UInt32 { rowSelection }

    public static let kanagawaDragon = ThemePalette(
        isDark: true, canvas: 0x24211F, text: 0xE2DED7,
        sidebar: 0x2B2825, input: 0x322E2B, border: 0x48413C,
        secondaryText: 0xB5ADA4, tertiaryText: 0xA29A91, accent: 0xC9B691,
        selection: 0x514638, rowSelection: 0x403A33, hover: 0x342F2B,
        heading: 0xD9C9AA, italic: 0xD2A294, code: 0xBDB5D2,
        link: 0xA8C4B0, quote: 0xB5ADA4, highlightBackground: 0x51442B,
        highlightText: 0xF0D49B
    )

    public static let light = ThemePalette(
        isDark: false, canvas: 0xFAFAF9, text: 0x343735,
        sidebar: 0xF1F1EF, input: 0xFFFFFF, border: 0xDEDEDA,
        secondaryText: 0x676C67, tertiaryText: 0x686E67, accent: 0x4B6B5B,
        selection: 0xD5E3D9, rowSelection: 0xE0E7E1, hover: 0xE9EEEA,
        heading: 0x3F574A, italic: 0x9D5B60, code: 0x6F6088,
        link: 0x3C6B5D, quote: 0x676C67, highlightBackground: 0xF2DF9B,
        highlightText: 0x62491F
    )

    public static let dark = ThemePalette(
        isDark: true, canvas: 0x24262A, text: 0xE2E5E9,
        sidebar: 0x2A2D31, input: 0x31353B, border: 0x43474E,
        secondaryText: 0xADB4BE, tertiaryText: 0x959DAA, accent: 0xB6C2D4,
        selection: 0x424C5C, rowSelection: 0x383F49, hover: 0x30363F,
        heading: 0xD5DFEC, italic: 0xD8ADB0, code: 0xBCB2D9,
        link: 0xA5C8C1, quote: 0xADB4BE, highlightBackground: 0x504831,
        highlightText: 0xF3DFA5
    )

    public static let dawn = ThemePalette(
        isDark: false, canvas: 0xFAF6EF, text: 0x413D37,
        sidebar: 0xF1EAE0, input: 0xFFFCF7, border: 0xDDD3C5,
        secondaryText: 0x6C6258, tertiaryText: 0x74685B, accent: 0x84694C,
        selection: 0xE6D5BB, rowSelection: 0xEAE0D2, hover: 0xF1E9DF,
        heading: 0x776044, italic: 0xA35C56, code: 0x7C648D,
        link: 0x4E705B, quote: 0x6C6258, highlightBackground: 0xF2DDA3,
        highlightText: 0x6C4B1E
    )

    public static let dusk = ThemePalette(
        isDark: true, canvas: 0x26232E, text: 0xE8E0EC,
        sidebar: 0x2D2937, input: 0x353040, border: 0x484052,
        secondaryText: 0xB8ACBF, tertiaryText: 0xA497AC, accent: 0xD5AECA,
        selection: 0x514155, rowSelection: 0x44384A, hover: 0x38313F,
        heading: 0xDBC0D4, italic: 0xE3B3A5, code: 0xC4B5E3,
        link: 0xB1CBCA, quote: 0xB8ACBF, highlightBackground: 0x51402D,
        highlightText: 0xECD0A1
    )

    public static let ocean = ThemePalette(
        isDark: true, canvas: 0x202830, text: 0xDCE6ED,
        sidebar: 0x26313A, input: 0x2D3944, border: 0x3F4D5B,
        secondaryText: 0xAFBFCC, tertiaryText: 0x94A7B8, accent: 0xAAC9E3,
        selection: 0x40566C, rowSelection: 0x354758, hover: 0x2D3C49,
        heading: 0xB7D2E8, italic: 0xD2B0A3, code: 0xC0BDE1,
        link: 0xA3C9C2, quote: 0xAFBFCC, highlightBackground: 0x504831,
        highlightText: 0xF0DAA2
    )

    public static let forest = ThemePalette(
        isDark: true, canvas: 0x222925, text: 0xDEE7DC,
        sidebar: 0x29322C, input: 0x313B34, border: 0x444F46,
        secondaryText: 0xB1C0AF, tertiaryText: 0x98AB98, accent: 0xB7C9A5,
        selection: 0x45523E, rowSelection: 0x3A4637, hover: 0x303C31,
        heading: 0xC7D5B9, italic: 0xD2B09A, code: 0xB9BECE,
        link: 0xA8CCC1, quote: 0xB1C0AF, highlightBackground: 0x4E4B2F,
        highlightText: 0xECDAA1
    )

}

public extension AppTheme {
    var palette: ThemePalette? {
        switch self {
        case .system: nil
        case .kanagawaDragon: .kanagawaDragon
        case .light: .light
        case .dark: .dark
        case .dawn: .dawn
        case .dusk: .dusk
        case .ocean: .ocean
        case .forest: .forest
        }
    }
}
