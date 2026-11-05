import Foundation
import Testing
@testable import SlipCore

@Suite("Release updates")
struct ReleaseUpdateTests {
    @Test("Versions compare numerically and treat missing components as zero")
    func numericVersions() throws {
        let old = try #require(ReleaseVersion("v0.2.2"))
        let new = try #require(ReleaseVersion("0.10.0"))
        #expect(new > old)
        #expect(ReleaseVersion("1") == ReleaseVersion("1.0.0"))
        #expect(ReleaseVersion("1.2-beta") == nil)
        #expect(ReleaseVersion("1.2garbage") == nil)
        #expect(ReleaseVersion("") == nil)
    }

    @Test("A stable release exposes the published notes and download without downgrading")
    func stableRelease() throws {
        let data = Data(#"{"tag_name":"v0.3.0","html_url":"https://github.com/berkinduz/slip-menu-note-app/releases/tag/v0.3.0","draft":false,"prerelease":false,"assets":[{"name":"Slip-v0.3.0-macos-arm64.dmg","browser_download_url":"https://github.com/berkinduz/slip-menu-note-app/releases/download/v0.3.0/Slip-v0.3.0-macos-arm64.dmg"}]}"#.utf8)
        let release = try JSONDecoder().decode(SlipRelease.self, from: data)
        #expect(release.isNewer(than: "0.2.2"))
        #expect(!release.isNewer(than: "0.3.0"))
        #expect(!release.isNewer(than: "0.4.0"))
        #expect(release.downloadURL.lastPathComponent == "Slip-v0.3.0-macos-arm64.dmg")
        #expect(release.notesURL.lastPathComponent == "v0.3.0")
    }

    @Test("Draft and prerelease metadata does not become an advertised update")
    func prerelease() throws {
        for field in ["draft", "prerelease"] {
            let payload: [String: Any] = ["tag_name": "v2.0.0", "html_url": "https://github.com/berkinduz/slip-menu-note-app/releases/tag/v2.0.0", "draft": field == "draft", "prerelease": field == "prerelease", "assets": []]
            let release = try JSONDecoder().decode(SlipRelease.self, from: JSONSerialization.data(withJSONObject: payload))
            #expect(!release.isNewer(than: "0.2.2"))
        }
    }

    @Test("Automatic checks are throttled for a day while the first check is due")
    func dailyChecks() {
        let now = Date(timeIntervalSince1970: 100_000)
        #expect(UpdateCheckSchedule.isDue(lastCheck: nil, now: now))
        #expect(!UpdateCheckSchedule.isDue(lastCheck: now.addingTimeInterval(-3600), now: now))
        #expect(UpdateCheckSchedule.isDue(lastCheck: now.addingTimeInterval(-86_401), now: now))
        #expect(!UpdateCheckSchedule.isDue(lastCheck: now.addingTimeInterval(3600), now: now))
    }
}
