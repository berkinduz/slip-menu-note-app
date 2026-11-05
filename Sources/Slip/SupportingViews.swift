import SwiftUI
import SlipCore

struct MarkdownGuideView: View {
    @Environment(\.slipStyle) private var style
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                SlipMark(size: 35)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Keyboard Shortcuts").font(.system(size: 19, weight: .semibold)).tracking(-0.5)
                }
                Spacer()
                IconButton(symbol: "xmark", label: "Close Guide") { dismiss() }
            }.padding(24)
            Hairline()
            ScrollView {
                VStack(alignment: .leading, spacing: 19) {
                    VStack(spacing: 11) {
                        shortcut("Quick Commands", "/")
                        shortcut("Open or Hide Slip", "⌃⌥N")
                        shortcut("New Note", "⌘N")
                        shortcut("Find a Note", "⌘F")
                        shortcut("Settings", "⌘,")
                        shortcut("Show / Hide Sidebar", "⇧⌘S")
                        shortcut("Toggle Current Task", "⌘↩")
                        shortcut("Indent / Outdent List", "Tab / ⇧Tab")
                        shortcut("Close and Save", "Esc")
                    }
                    Hairline()
                    Text("A Little Markdown").font(.system(size: 14, weight: .semibold))
                    VStack(spacing: 11) {
                        syntax("# A heading", "Headings", "⌘⇧H")
                        syntax("**bold**", "Bold", "⌘B")
                        syntax("_italic_", "Italic", "⌘I")
                        syntax("==highlight==", "Highlight", "⌘⇧M")
                        syntax("- A list item", "Bullet List", "⌘⇧L")
                        syntax("- [ ] A task", "Task List", "⌘⇧T")
                        syntax("[text](url)", "Link", "⌘K")
                        syntax("`code`", "Inline Code", "⌘E")
                    }
                    Text("Type / to insert a heading, list, task, code block, quote, divider, or link. Keep typing to filter; use ↑↓ and Return to choose. Esc dismisses the menu. Return continues a list; Return again on an empty item ends it. Paste a URL over selected text to make a link.")
                        .font(.system(size: 11)).lineSpacing(4).foregroundStyle(style.secondary)
                }.padding(24)
            }
            Hairline()
            HStack {
                Label("Your notes stay on this Mac.", systemImage: "internaldrive")
                    .font(.system(size: 11)).foregroundStyle(style.secondary)
                Spacer()
                Button("Got It") { dismiss() }.keyboardShortcut(.defaultAction)
            }.padding(.horizontal, 24).padding(.vertical, 15)
        }
        .frame(width: 465, height: 560)
        .background(style.canvas)
    }

    private func shortcut(_ title: String, _ keys: String) -> some View {
        HStack { Text(title).font(.system(size: 12)); Spacer(); KeyCap(text: keys) }
    }
    private func syntax(_ source: String, _ name: String, _ keys: String) -> some View {
        HStack {
            Text(source).font(.system(size: 11, design: .monospaced)).foregroundStyle(style.accent).frame(width: 160, alignment: .leading)
            Text(name).font(.system(size: 11)).foregroundStyle(style.secondary)
            Spacer()
            KeyCap(text: keys)
        }
    }
}
