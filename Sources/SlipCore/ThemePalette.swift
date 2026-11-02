// Kanagawa Dragon colors from metaphore.kanagawa-vscode-color-theme 1.2.0.
// Copyright (c) 2025 Pierre-Alain Castella, MIT. See THIRD-PARTY-NOTICES.txt.
public struct ThemePalette: Equatable, Sendable {
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
    public let popup: UInt32
    public let popupSelection: UInt32
    public let heading: UInt32
    public let italic: UInt32
    public let code: UInt32
    public let link: UInt32
    public let quote: UInt32

    public static let kanagawaDragon = ThemePalette(
        canvas: 0x181616, text: 0xC5C9C5, sidebar: 0x181616,
        input: 0x0D0C0C, border: 0x0D0C0C,
        secondaryText: 0xA6A69C, tertiaryText: 0x737C73,
        accent: 0x8BA4B0, selection: 0x223249, rowSelection: 0x393836,
        hover: 0x282727, popup: 0x223249, popupSelection: 0x2D4F67,
        heading: 0x8BA4B0, italic: 0xC4746E, code: 0x8992A7,
        link: 0x6A9589, quote: 0x737C73
    )
}
