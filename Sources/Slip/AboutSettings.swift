import AppKit
import SwiftUI

struct AboutSettings: View {
    @Environment(\.slipStyle) private var style

    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text("Slip")
                    .font(.system(size: 25, weight: .semibold))
                if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                    Text("Version \(version)")
                        .font(.caption)
                        .foregroundStyle(style.secondary)
                }
            }

            Text("Quick notes. Always within reach.")
                .font(.callout)
                .foregroundStyle(style.secondary)

            VStack(spacing: 14) {
                Link(destination: URL(string: "https://github.com/berkinduz")!) {
                    Label("Made by berkinduz", systemImage: "person.crop.circle")
                }
                Link(destination: URL(string: "https://github.com/berkinduz/slip-menu-note-app")!) {
                    Label("Source code & contributions", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(style.accent)

            Link(destination: URL(string: "https://buymeacoffee.com/berkinduz")!) {
                Label("Buy me a coffee", systemImage: "cup.and.saucer")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(style.accent)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(style.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                    .contentShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)

            Text("Free to use. Open to contributions.")
                .font(.caption)
                .foregroundStyle(style.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .background(style.canvas, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(style.line.opacity(0.5), lineWidth: 0.5))
    }
}
