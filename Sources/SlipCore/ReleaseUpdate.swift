import Foundation

public struct ReleaseVersion: Comparable, Sendable {
    private let components: [Int]

    public init?(_ value: String) {
        let value = value.hasPrefix("v") ? String(value.dropFirst()) : value
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(parts.count),
              parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy({ $0.isASCII && $0.isNumber }) }) else { return nil }
        let numbers = parts.compactMap { Int($0) }
        guard numbers.count == parts.count else { return nil }
        components = numbers + Array(repeating: 0, count: 3 - numbers.count)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.components.lexicographicallyPrecedes(rhs.components)
    }
}

public struct SlipRelease: Decodable, Sendable {
    public let tagName: String
    public let notesURL: URL
    public let draft: Bool
    public let prerelease: Bool
    private let assets: [Asset]

    private struct Asset: Decodable, Sendable {
        let name: String
        let url: URL
        enum CodingKeys: String, CodingKey {
            case name
            case url = "browser_download_url"
        }
    }

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case notesURL = "html_url"
        case draft, prerelease, assets
    }

    public var downloadURL: URL {
        assets.first { $0.name.hasSuffix("-macos-arm64.dmg") }?.url ?? notesURL
    }

    public var updateArchiveURL: URL? {
        assets.first { $0.name == "Slip-\(tagName)-macos-arm64.zip" }?.url
    }

    public var checksumsURL: URL? {
        assets.first { $0.name == "SHA256SUMS.txt" }?.url
    }

    public func isNewer(than current: String) -> Bool {
        guard !draft, !prerelease, let version = ReleaseVersion(tagName), let installed = ReleaseVersion(current) else { return false }
        return version > installed
    }
}

public enum UpdateCheckSchedule {
    public static func isDue(lastCheck: Date?, now: Date = .now) -> Bool {
        guard let lastCheck else { return true }
        return now.timeIntervalSince(lastCheck) >= 86_400
    }
}
