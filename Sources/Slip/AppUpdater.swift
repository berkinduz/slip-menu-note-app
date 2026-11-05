import CryptoKit
import Foundation
import SlipCore

struct AppUpdater: Sendable {
    let applicationURL: URL
    let executableURL: URL?
    let relaunchArguments: [String]
    let download: @Sendable (URL) async throws -> Data

    init(applicationURL: URL = Bundle.main.bundleURL,
         executableURL: URL? = Bundle.main.executableURL,
         relaunchArguments: [String] = Array(ProcessInfo.processInfo.arguments.dropFirst()),
         download: @escaping @Sendable (URL) async throws -> Data = AppUpdater.download) {
        self.applicationURL = applicationURL
        self.executableURL = executableURL
        self.relaunchArguments = relaunchArguments
        self.download = download
    }

    func prepare(_ release: SlipRelease) async throws -> PreparedAppUpdate {
        guard let archiveURL = release.updateArchiveURL, let checksumsURL = release.checksumsURL else {
            throw AppUpdateError.missingPackage
        }
        let manager = FileManager.default
        guard applicationURL.pathExtension == "app", let executableURL,
              manager.isWritableFile(atPath: applicationURL.path),
              manager.isWritableFile(atPath: applicationURL.deletingLastPathComponent().path) else {
            throw AppUpdateError.notWritable
        }
        let directory = try manager.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: applicationURL, create: true)
        var prepared = false
        defer { if !prepared { try? manager.removeItem(at: directory) } }

        let archive = try await download(archiveURL)
        let checksums = try await download(checksumsURL)
        let digest = SHA256.hash(data: archive).map { String(format: "%02x", $0) }.joined()
        let checksumMatches = String(decoding: checksums, as: UTF8.self).split(whereSeparator: \.isNewline).contains { line in
            let parts = line.split(whereSeparator: \.isWhitespace)
            return parts.count == 2 && parts[0].lowercased() == digest && parts[1] == archiveURL.lastPathComponent
        }
        guard checksumMatches else { throw AppUpdateError.damagedDownload }

        let zip = directory.appendingPathComponent("update.zip")
        try archive.write(to: zip)
        let extracted = directory.appendingPathComponent("extracted", isDirectory: true)
        try UpdateProcess.run("/usr/bin/ditto", ["-x", "-k", zip.path, extracted.path])
        let updated = extracted.appendingPathComponent("Slip.app", isDirectory: true)
        let info = try PropertyListSerialization.propertyList(from: Data(contentsOf: updated.appendingPathComponent("Contents/Info.plist")), format: nil) as? [String: Any]
        guard info?["CFBundleIdentifier"] as? String == "local.slip.notes",
              let version = info?["CFBundleShortVersionString"] as? String,
              let expectedVersion = ReleaseVersion(release.tagName), ReleaseVersion(version) == expectedVersion else {
            throw AppUpdateError.invalidPackage
        }
        try UpdateProcess.run("/usr/bin/codesign", ["--verify", "--deep", "--strict", updated.path])

        let update = PreparedAppUpdate(directory: directory, applicationURL: updated, targetURL: applicationURL,
                                       relaunchArguments: relaunchArguments, parentProcessID: getpid())
        // The helper must live outside Slip.app so replacing the bundle cannot remove it.
        try manager.copyItem(at: executableURL, to: update.helperURL)
        prepared = true
        return update
    }

    private static func download(_ url: URL) async throws -> Data {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.timeoutIntervalForRequest = 60
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(from: url)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw AppUpdateError.downloadFailed
        }
        return data
    }
}

struct PreparedAppUpdate: Codable, Sendable {
    let directory: URL
    let applicationURL: URL
    let targetURL: URL
    let relaunchArguments: [String]
    let parentProcessID: Int32

    var helperURL: URL { directory.appendingPathComponent("SlipUpdate") }

    func discard() { try? FileManager.default.removeItem(at: directory) }

    func launchInstaller() throws {
        let planURL = directory.appendingPathComponent("update.json")
        try JSONEncoder().encode(self).write(to: planURL, options: .atomic)
        let process = Process()
        process.executableURL = helperURL
        process.arguments = ["--complete-update", planURL.path]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
    }

    static func complete(at planURL: URL) throws {
        let update = try JSONDecoder().decode(Self.self, from: Data(contentsOf: planURL))
        // Launched only after the normal quit/save decision. Do not replace a running app.
        while getppid() == update.parentProcessID { Thread.sleep(forTimeInterval: 0.1) }
        try update.installAndRelaunch()
    }

    func installAndRelaunch(open: (URL, [String]) throws -> Void = PreparedAppUpdate.open) throws {
        let manager = FileManager.default
        let backupName = ".Slip-backup-\(UUID().uuidString).app"
        let backupURL = targetURL.deletingLastPathComponent().appendingPathComponent(backupName)
        var replaced = false
        defer { discard() }
        do {
            _ = try manager.replaceItemAt(targetURL, withItemAt: applicationURL, backupItemName: backupName,
                                          options: [.usingNewMetadataOnly, .withoutDeletingBackupItem])
            replaced = true
            try open(targetURL, relaunchArguments)
        } catch {
            if replaced {
                _ = try manager.replaceItemAt(targetURL, withItemAt: backupURL, options: .usingNewMetadataOnly)
            }
            try? open(targetURL, relaunchArguments)
            throw error
        }
        try? manager.removeItem(at: backupURL)
    }

    private static func open(_ application: URL, _ arguments: [String]) throws {
        try UpdateProcess.run("/usr/bin/open", ["-n", application.path] + (arguments.isEmpty ? [] : ["--args"] + arguments))
    }
}

private enum UpdateProcess {
    static func run(_ executable: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationReason == .exit, process.terminationStatus == 0 else { throw AppUpdateError.invalidPackage }
    }
}

enum AppUpdateError: LocalizedError, Equatable {
    case missingPackage, notWritable, damagedDownload, invalidPackage, downloadFailed

    var errorDescription: String? {
        switch self {
        case .missingPackage: "This release doesn’t include an in-app update package."
        case .notWritable: "Slip can’t update in this location. Move it to a writable Applications folder and try again."
        case .damagedDownload: "The update download is incomplete or damaged. Try again."
        case .invalidPackage: "The update package couldn’t be installed or verified."
        case .downloadFailed: "The update couldn’t be downloaded. Try again later."
        }
    }
}
