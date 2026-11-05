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

    @Test("The update button prepares once, requests normal termination, and can cancel without installing")
    func prepareAndCancelInstallation() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let staging = directory.appendingPathComponent("update")
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        let prepared = PreparedAppUpdate(directory: staging, applicationURL: staging.appendingPathComponent("Slip.app"),
                                         targetURL: directory.appendingPathComponent("Slip.app"), relaunchArguments: [], parentProcessID: getpid())
        let published = try release()
        var terminationRequests = 0
        let controller = UpdateController(settings: PreferencesStore(directory: directory), installedVersion: "0.3.0",
                                          fetchRelease: { published }, prepareUpdate: { _ in prepared }, requestTermination: { terminationRequests += 1 })
        await controller.check()
        await controller.installUpdate()
        #expect(controller.isInstalling)
        #expect(terminationRequests == 1)
        #expect(FileManager.default.fileExists(atPath: staging.path))
        await controller.installUpdate()
        #expect(terminationRequests == 1)
        controller.cancelInstallation()
        #expect(!controller.isInstalling)
        #expect(!FileManager.default.fileExists(atPath: staging.path))
        #expect(controller.availableRelease?.tagName == "v0.4.0")
    }

    @Test("Download failure keeps Slip open and permits another attempt")
    func failedInstallation() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let published = try release()
        var terminated = false
        let controller = UpdateController(settings: PreferencesStore(directory: directory), installedVersion: "0.3.0", fetchRelease: { published },
                                          prepareUpdate: { _ in throw URLError(.notConnectedToInternet) }, requestTermination: { terminated = true })
        await controller.check()
        await controller.installUpdate()
        #expect(!controller.isInstalling)
        #expect(controller.errorMessage != nil)
        #expect(!terminated)
        await controller.installUpdate()
        #expect(!controller.isInstalling)
        #expect(controller.availableRelease?.tagName == "v0.4.0")
        #expect(!terminated)
    }

    @Test("An installer that cannot start cancels termination and preserves the offered update")
    func failedInstallerLaunch() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let staging = directory.appendingPathComponent("update")
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        let prepared = PreparedAppUpdate(directory: staging, applicationURL: staging.appendingPathComponent("Slip.app"),
                                         targetURL: directory.appendingPathComponent("Slip.app"), relaunchArguments: [], parentProcessID: getpid())
        let published = try release()
        let controller = UpdateController(settings: PreferencesStore(directory: directory), installedVersion: "0.3.0", fetchRelease: { published },
                                          prepareUpdate: { _ in prepared }, requestTermination: {})
        await controller.check()
        await controller.installUpdate()
        #expect(!controller.launchPendingInstaller())
        #expect(!controller.isInstalling)
        #expect(controller.errorMessage != nil)
        #expect(!FileManager.default.fileExists(atPath: staging.path))
        #expect(controller.availableRelease?.tagName == "v0.4.0")
    }

    @Test("Cancelling quit during a download prevents its later completion from quitting Slip again")
    func cancelWhileDownloading() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let staging = directory.appendingPathComponent("update")
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        let prepared = PreparedAppUpdate(directory: staging, applicationURL: staging.appendingPathComponent("Slip.app"),
                                         targetURL: directory.appendingPathComponent("Slip.app"), relaunchArguments: [], parentProcessID: getpid())
        let download = AsyncStream<PreparedAppUpdate>.makeStream()
        let published = try release()
        var terminated = false
        let controller = UpdateController(settings: PreferencesStore(directory: directory), installedVersion: "0.3.0", fetchRelease: { published },
                                          prepareUpdate: { _ in
                                              var iterator = download.stream.makeAsyncIterator()
                                              return try #require(await iterator.next())
                                          }, requestTermination: { terminated = true })
        await controller.check()
        let operation = Task { await controller.installUpdate() }
        while !controller.isInstalling { await Task.yield() }
        controller.cancelInstallation()
        download.continuation.yield(prepared)
        download.continuation.finish()
        await operation.value
        #expect(!terminated)
        #expect(!controller.isInstalling)
        #expect(!FileManager.default.fileExists(atPath: staging.path))
    }
}
