import CryptoKit
import Foundation
import Testing
import SlipCore
@testable import Slip

@Suite("In-app installation")
struct AppUpdaterTests {
    @Test("Preparing an update verifies the published archive without changing the installed app")
    func prepare() async throws {
        let fixture = try UpdateFixture()
        defer { fixture.remove() }
        let archive = try fixture.archive()
        let prepared = try await fixture.updater(archive: archive).prepare(fixture.release)
        defer { prepared.discard() }
        #expect(try fixture.version(at: fixture.installed) == "0.3.0")
        #expect(try fixture.version(at: prepared.applicationURL) == "0.4.0")
        #expect(FileManager.default.isExecutableFile(atPath: prepared.helperURL.path))
    }

    @Test("A damaged download never replaces the installed version")
    func damagedDownload() async throws {
        let fixture = try UpdateFixture()
        defer { fixture.remove() }
        await #expect(throws: AppUpdateError.damagedDownload) {
            _ = try await fixture.updater(archive: Data("damaged".utf8), checksum: String(repeating: "0", count: 64)).prepare(fixture.release)
        }
        #expect(try fixture.version(at: fixture.installed) == "0.3.0")
    }

    @Test("A signed package for the wrong version is rejected")
    func wrongVersion() async throws {
        let fixture = try UpdateFixture(version: "9.0.0")
        defer { fixture.remove() }
        let archive = try fixture.archive()
        await #expect(throws: AppUpdateError.invalidPackage) {
            _ = try await fixture.updater(archive: archive).prepare(fixture.release)
        }
        #expect(try fixture.version(at: fixture.installed) == "0.3.0")
    }

    @Test("A package with broken code signing is rejected even when its checksum matches")
    func brokenSignature() async throws {
        let fixture = try UpdateFixture()
        defer { fixture.remove() }
        try Data("changed".utf8).write(to: fixture.updated.appendingPathComponent("Contents/Resources/content.txt"))
        let archive = try fixture.archive()
        await #expect(throws: AppUpdateError.invalidPackage) {
            _ = try await fixture.updater(archive: archive).prepare(fixture.release)
        }
        #expect(try fixture.version(at: fixture.installed) == "0.3.0")
    }

    @Test("Installation replaces the app at its existing path and relaunches with its arguments")
    func installAndRelaunch() throws {
        let fixture = try UpdateFixture()
        defer { fixture.remove() }
        let prepared = fixture.prepared()
        var launched = false
        try prepared.installAndRelaunch { application, arguments in
            #expect(application == fixture.installed)
            #expect(arguments == ["--data-dir", fixture.directory.appendingPathComponent("notes").path])
            #expect(try fixture.version(at: application) == "0.4.0")
            try UpdateFixture.run("/usr/bin/codesign", ["--verify", "--deep", "--strict", application.path])
            launched = true
        }
        #expect(launched)
        #expect(try fixture.version(at: fixture.installed) == "0.4.0")
        #expect(!FileManager.default.fileExists(atPath: prepared.directory.path))
        let remaining = try FileManager.default.contentsOfDirectory(atPath: fixture.directory.path)
        #expect(!remaining.contains { $0.contains("backup") })
    }

    @Test("A failed relaunch restores and reopens the previous app")
    func rollback() throws {
        let fixture = try UpdateFixture()
        defer { fixture.remove() }
        var launchedVersions: [String] = []
        #expect(throws: (any Error).self) {
            try fixture.prepared().installAndRelaunch { application, _ in
                launchedVersions.append(try fixture.version(at: application))
                if launchedVersions.count == 1 { throw CocoaError(.executableNotLoadable) }
            }
        }
        #expect(launchedVersions == ["0.4.0", "0.3.0"])
        #expect(try fixture.version(at: fixture.installed) == "0.3.0")
    }

    @Test("The detached installer waits for Slip to exit, then installs and really reopens the app")
    func detachedInstaller() async throws {
        let fixture = try UpdateFixture()
        defer { fixture.remove() }
        let output = fixture.directory.appendingPathComponent("reopened.txt")
        let source = fixture.directory.appendingPathComponent("probe.c")
        try "#include <stdio.h>\nint main(int argc, char **argv) { if (argc != 2) return 1; FILE *f = fopen(argv[1], \"w\"); if (!f) return 2; fputs(\"reopened 0.4.0\", f); return fclose(f); }\n".write(to: source, atomically: true, encoding: .utf8)
        try UpdateFixture.run("/usr/bin/clang", [source.path, "-o", fixture.updated.appendingPathComponent("Contents/MacOS/Slip").path])
        let infoURL = fixture.updated.appendingPathComponent("Contents/Info.plist")
        var info = try #require(PropertyListSerialization.propertyList(from: Data(contentsOf: infoURL), format: nil) as? [String: Any])
        // LaunchServices must not register the probe as the user's real Slip app.
        info["CFBundleIdentifier"] = "local.slip.updater-test.\(UUID().uuidString)"
        info["LSUIElement"] = true
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: infoURL)
        try UpdateFixture.run("/usr/bin/codesign", ["--force", "--sign", "-", fixture.updated.path])

        let binary = Bundle(for: UpdateTestBundle.self).bundleURL.deletingLastPathComponent().appendingPathComponent("Slip")
        try #require(FileManager.default.isExecutableFile(atPath: binary.path))
        let helper = fixture.updated.deletingLastPathComponent().appendingPathComponent("SlipUpdate")
        try FileManager.default.copyItem(at: binary, to: helper)
        let plan = fixture.directory.appendingPathComponent("plan.json")
        let started = fixture.directory.appendingPathComponent("started")
        let exitSignal = fixture.directory.appendingPathComponent("exit")
        let parent = Process()
        parent.executableURL = URL(fileURLWithPath: "/bin/sh")
        parent.arguments = ["-c", """
        while [ ! -e "$2" ]; do sleep 0.05; done
        "$1" --complete-update "$2" &
        printf '%s' "$!" > "$3"
        while [ ! -e "$4" ]; do sleep 0.05; done
        """, "update-test", helper.path, plan.path, started.path, exitSignal.path]
        parent.standardOutput = FileHandle.nullDevice
        parent.standardError = FileHandle.nullDevice
        try parent.run()
        defer { if parent.isRunning { parent.terminate() } }
        let prepared = PreparedAppUpdate(directory: fixture.updated.deletingLastPathComponent(), applicationURL: fixture.updated,
                                         targetURL: fixture.installed, relaunchArguments: [output.path], parentProcessID: parent.processIdentifier)
        try JSONEncoder().encode(prepared).write(to: plan, options: .atomic)
        try await waitForFile(started)
        try await Task.sleep(for: .milliseconds(200))
        #expect(try fixture.version(at: fixture.installed) == "0.3.0")
        #expect(!FileManager.default.fileExists(atPath: output.path))
        try Data().write(to: exitSignal)
        try await waitForFile(output)
        #expect(try String(contentsOf: output, encoding: .utf8) == "reopened 0.4.0")
        #expect(try fixture.version(at: fixture.installed) == "0.4.0")
        try await waitForRemoval(prepared.directory)
    }

    private func waitForFile(_ url: URL) async throws {
        for _ in 0..<200 {
            if FileManager.default.fileExists(atPath: url.path) { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        Issue.record("Timed out waiting for \(url.lastPathComponent)")
        throw CocoaError(.fileNoSuchFile)
    }

    private func waitForRemoval(_ url: URL) async throws {
        for _ in 0..<200 {
            if !FileManager.default.fileExists(atPath: url.path) { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        Issue.record("The installer did not remove its staging directory")
    }
}

private final class UpdateTestBundle: NSObject {}

private struct UpdateFixture: Sendable {
    let directory: URL
    let installed: URL
    let updated: URL
    let release: SlipRelease

    init(version: String = "0.4.0") throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("Slip updater '\(UUID().uuidString)", isDirectory: true)
        installed = directory.appendingPathComponent("Slip.app")
        updated = directory.appendingPathComponent("staging/Slip.app")
        release = try JSONDecoder().decode(SlipRelease.self, from: Data(#"{"tag_name":"v0.4.0","html_url":"https://github.com/berkinduz/slip-menu-note-app/releases/tag/v0.4.0","draft":false,"prerelease":false,"assets":[{"name":"Slip-v0.4.0-macos-arm64.zip","browser_download_url":"https://example.com/Slip-v0.4.0-macos-arm64.zip"},{"name":"SHA256SUMS.txt","browser_download_url":"https://example.com/SHA256SUMS.txt"}]}"#.utf8))
        try Self.makeApp(at: installed, version: "0.3.0")
        try Self.makeApp(at: updated, version: version)
    }

    func remove() { try? FileManager.default.removeItem(at: directory) }

    func version(at application: URL) throws -> String {
        let data = try Data(contentsOf: application.appendingPathComponent("Contents/Info.plist"))
        let plist = try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        return try #require(plist["CFBundleShortVersionString"] as? String)
    }

    func archive() throws -> Data {
        let archive = directory.appendingPathComponent("update.zip")
        try Self.run("/usr/bin/ditto", ["-c", "-k", "--sequesterRsrc", "--keepParent", updated.path, archive.path])
        return try Data(contentsOf: archive)
    }

    func updater(archive: Data, checksum: String? = nil) -> AppUpdater {
        let digest = checksum ?? SHA256.hash(data: archive).map { String(format: "%02x", $0) }.joined()
        return AppUpdater(applicationURL: installed, executableURL: installed.appendingPathComponent("Contents/MacOS/Slip"), relaunchArguments: []) { url in
            switch url.lastPathComponent {
            case "Slip-v0.4.0-macos-arm64.zip": return archive
            case "SHA256SUMS.txt": return Data("\(digest)  Slip-v0.4.0-macos-arm64.zip\n".utf8)
            default: throw URLError(.fileDoesNotExist)
            }
        }
    }

    func prepared() -> PreparedAppUpdate {
        PreparedAppUpdate(directory: updated.deletingLastPathComponent(), applicationURL: updated, targetURL: installed,
                          relaunchArguments: ["--data-dir", directory.appendingPathComponent("notes").path], parentProcessID: getpid())
    }

    static func makeApp(at url: URL, version: String) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: url.appendingPathComponent("Contents/MacOS"), withIntermediateDirectories: true)
        try manager.createDirectory(at: url.appendingPathComponent("Contents/Resources"), withIntermediateDirectories: true)
        try manager.copyItem(at: URL(fileURLWithPath: "/usr/bin/true"), to: url.appendingPathComponent("Contents/MacOS/Slip"))
        let plist = ["CFBundleIdentifier": "local.slip.notes", "CFBundleExecutable": "Slip", "CFBundlePackageType": "APPL", "CFBundleShortVersionString": version]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: url.appendingPathComponent("Contents/Info.plist"))
        try Data("original".utf8).write(to: url.appendingPathComponent("Contents/Resources/content.txt"))
        try run("/usr/bin/codesign", ["--force", "--sign", "-", url.path])
    }

    static func run(_ executable: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }
}
