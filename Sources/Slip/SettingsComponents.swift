import SwiftUI
import SlipCore

struct SettingsSection<Content: View>: View {
    @Environment(\.slipStyle) private var style
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(style.secondary)
                .padding(.leading, 3)
            VStack(spacing: 0) { content }
                .padding(14).frame(maxWidth: .infinity)
                .background(style.input.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(style.line.opacity(0.55), lineWidth: 0.5))
        }
    }
}

struct SettingsRow<Control: View>: View {
    @Environment(\.slipStyle) private var style
    let title: String
    var detail: String?
    @ViewBuilder var control: Control

    init(_ title: String, detail: String? = nil, @ViewBuilder control: () -> Control) {
        self.title = title
        self.detail = detail
        self.control = control()
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13))
                if let detail { Text(detail).font(.system(size: 11)).foregroundStyle(style.secondary).fixedSize(horizontal: false, vertical: true) }
            }
            Spacer(minLength: 8)
            control
        }
        .frame(minHeight: detail == nil ? 36 : 46)
    }
}

struct SettingsToggle: View {
    let title: String
    var detail: String?
    @Binding var value: Bool

    init(_ title: String, detail: String? = nil, value: Binding<Bool>) {
        self.title = title
        self.detail = detail
        self._value = value
    }

    var body: some View {
        SettingsRow(title, detail: detail) {
            Toggle(title, isOn: $value).labelsHidden().toggleStyle(.switch).controlSize(.small)
        }
    }
}

struct SettingsSlider: View {
    @Environment(\.slipStyle) private var style
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let suffix: String

    init(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String) {
        self.title = title
        self._value = value
        self.range = range
        self.suffix = suffix
    }

    var body: some View {
        SettingsRow(title) {
            Slider(value: $value, in: range, step: 1).frame(width: 150).accessibilityLabel(title)
            Text("\(Int(value)) \(suffix)").font(.system(size: 12)).monospacedDigit()
                .foregroundStyle(style.secondary).frame(width: 45, alignment: .trailing)
        }
    }
}

struct SettingsDivider: View {
    @Environment(\.slipStyle) private var style
    var body: some View { Rectangle().fill(style.line.opacity(0.65)).frame(height: 0.5).padding(.vertical, 7) }
}

struct ThemeChoice: View {
    @Environment(\.slipStyle) private var style
    let theme: AppTheme
    let selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Group {
                    if let palette = theme.palette { ThemeThumbnail(palette: palette) }
                    else {
                        HStack(spacing: 0) {
                            Text("Aa").foregroundStyle(Color(nsColor: NSColor(rgb: ThemePalette.light.text)))
                                .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(nsColor: NSColor(rgb: ThemePalette.light.canvas)))
                            Text("Aa").foregroundStyle(Color(nsColor: NSColor(rgb: ThemePalette.dark.text)))
                                .frame(maxWidth: .infinity, maxHeight: .infinity).background(Color(nsColor: NSColor(rgb: ThemePalette.dark.canvas)))
                        }.font(.system(size: 15, weight: .medium))
                    }
                }
                .frame(height: 48).clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(selected ? style.accent : style.line, lineWidth: selected ? 2 : 0.5))
                HStack(spacing: 4) {
                    Text(theme.title).lineLimit(1)
                    if selected { Image(systemName: "checkmark.circle.fill").font(.system(size: 10)) }
                }
                .font(.system(size: 11, weight: selected ? .medium : .regular))
                .foregroundStyle(selected ? style.text : style.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).accessibilityLabel("\(theme.title) theme")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityRemoveTraits(selected ? [] : .isSelected)
    }
}

private struct ThemeThumbnail: View {
    let palette: ThemePalette
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Capsule().fill(color(palette.accent).opacity(0.5)).frame(width: 12, height: 3)
                Capsule().fill(color(palette.secondaryText).opacity(0.25)).frame(width: 17, height: 3)
                Spacer(minLength: 0)
            }.padding(8).frame(width: 32).background(color(palette.sidebar))
            VStack(alignment: .leading, spacing: 5) {
                Capsule().fill(color(palette.heading)).frame(width: 37, height: 4)
                Capsule().fill(color(palette.text).opacity(0.5)).frame(maxWidth: .infinity).frame(height: 3)
                Capsule().fill(color(palette.text).opacity(0.28)).frame(width: 30, height: 3)
                Spacer(minLength: 0)
            }.padding(9).frame(maxWidth: .infinity, alignment: .leading)
        }.background(color(palette.canvas))
    }
    private func color(_ value: UInt32) -> Color { Color(nsColor: NSColor(rgb: value)) }
}

struct AccentChoice: View {
    @Environment(\.slipStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    let choice: AccentColor
    let selected: Bool
    var action: () -> Void

    private var color: Color {
        choice.rgb(dark: colorScheme == .dark).map { Color(nsColor: NSColor(rgb: $0)) } ?? SlipStyle(theme: style.theme).accent
    }

    var body: some View {
        Button(action: action) {
            Circle().fill(color).frame(width: 27, height: 27)
                .overlay {
                    if selected {
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(style.canvas)
                    } else if choice == .theme {
                        Image(systemName: "paintpalette").font(.system(size: 12)).foregroundStyle(style.canvas)
                    }
                }
                .padding(3)
                .overlay(Circle().strokeBorder(selected ? color.opacity(0.75) : .clear, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain).help(choice == .theme ? "Use the theme accent" : choice.title)
        .accessibilityLabel("\(choice.title) accent").accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityRemoveTraits(selected ? [] : .isSelected)
    }
}

struct SettingsPreview: View {
    @Environment(\.slipStyle) private var style
    @Environment(\.editorPreferences) private var preferences
    @State private var noteID = UUID()
    @State private var focusID = UUID()
    private let sample = "## A little room to think\nAn **idea**. ==A little focus==.\n- [ ] Send the update\n- [x] Find your rhythm"

    private var previewHeight: Double {
        max(154, max(preferences.lineHeight, (preferences.fontSize + 5) * 1.5)
            + preferences.lineHeight * 3 + preferences.paragraphSpacing * 4 + 32)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("Live preview").font(.system(size: 12, weight: .medium))
                Spacer()
                Text("Aa").font(.system(size: 11))
            }.foregroundStyle(style.secondary).padding(.horizontal, 3)
            MarkdownEditor(text: .constant(sample), noteID: noteID, focusRequest: focusID, isActive: false,
                           initialSelection: NSRange(location: 0, length: 0), selectionChanged: { _ in }, onFocus: {}, onLinkChanged: { _ in })
                .frame(height: previewHeight).allowsHitTesting(false).accessibilityLabel("Note appearance preview")
                .background(style.canvas, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(style.line.opacity(0.75), lineWidth: 0.5))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}
