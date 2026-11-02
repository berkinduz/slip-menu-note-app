import Foundation

public enum ShortcutKey {
    public static func canonical(_ characters: String) -> String {
        characters.lowercased()
            .replacingOccurrences(of: "ı", with: "i")
            .replacingOccurrences(of: "i\u{307}", with: "i")
    }
}
