import Foundation
import Testing
import SlipCore
@testable import Slip

@Suite("Update check flow", .serialized)
@MainActor
struct UpdateControllerTests {
    private func release() throws -> SlipRelease {
        try JSONDecoder().decode(SlipRelease.self, from: Data(#"{"tag_name":"v0.4.0","html_url":"https://github.com/berkinduz/slip-menu-note-app/releases/tag/v0.4.0","draft":false,"prerelease":false,"assets":[]}"#.utf8))
    }

    @Test("Manual checks still work when automatic checks are disabled or not due")
    func manualCheck() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let settings = PreferencesStore(directory: directory)
        settings.preferences.automaticallyCheckUpdates = false
        let published = try release()
        let controller = UpdateController(settings: settings, installedVersion: "0.3.0", fetchRelease: { published })
        await controller.check(automatic: true)
        #expect(controller.availableRelease == nil)
        #expect(settings.preferences.lastUpdateCheck == nil)
        let now = Date(timeIntervalSince1970: 200_000)
        await controller.check(now: now)
        #expect(controller.availableRelease?.tagName == "v0.4.0")
        #expect(settings.preferences.lastUpdateCheck == now)
        #expect(!controller.isChecking)
    }

    @Test("A failed automatic request is retried manually without repeatedly checking in the background")
    func failedRequest() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let settings = PreferencesStore(directory: directory)
        let controller = UpdateController(settings: settings, installedVersion: "0.3.0", fetchRelease: { throw URLError(.notConnectedToInternet) })
        let now = Date(timeIntervalSince1970: 200_000)
        await controller.check(automatic: true, now: now)
        #expect(controller.errorMessage != nil)
        #expect(!controller.isChecking)
        await controller.check(automatic: true, now: now.addingTimeInterval(3600))
        #expect(settings.preferences.lastUpdateCheck == now)
        await controller.check(now: now.addingTimeInterval(3600))
        #expect(settings.preferences.lastUpdateCheck == now.addingTimeInterval(3600))
    }
}
