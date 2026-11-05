import Foundation
import Observation
import SlipCore

@MainActor @Observable
final class UpdateController {
    private(set) var isChecking = false
    private(set) var availableRelease: SlipRelease?
    private(set) var message: String?
    private(set) var errorMessage: String?
    let installedVersion: String
    @ObservationIgnored private let settings: PreferencesStore
    @ObservationIgnored private let fetchRelease: @Sendable () async throws -> SlipRelease
    @ObservationIgnored private var timer: Task<Void, Never>?

    init(settings: PreferencesStore,
         installedVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.3.0",
         fetchRelease: @escaping @Sendable () async throws -> SlipRelease = UpdateController.fetchPublicRelease) {
        self.settings = settings
        self.installedVersion = installedVersion
        self.fetchRelease = fetchRelease
    }

    func start() {
        timer?.cancel()
        timer = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(5)) } catch { return }
            while !Task.isCancelled {
                await self?.check(automatic: true)
                do { try await Task.sleep(for: .seconds(3600)) } catch { return }
            }
        }
    }

    func stop() { timer?.cancel(); timer = nil }

    func check(automatic: Bool = false, now: Date = .now) async {
        guard !isChecking else { return }
        if automatic {
            guard settings.preferences.automaticallyCheckUpdates,
                  UpdateCheckSchedule.isDue(lastCheck: settings.preferences.lastUpdateCheck, now: now) else { return }
        }
        isChecking = true
        errorMessage = nil
        message = nil
        settings.preferences.lastUpdateCheck = now
        defer { isChecking = false }
        do {
            let release = try await fetchRelease()
            availableRelease = release.isNewer(than: installedVersion) ? release : nil
            message = availableRelease == nil ? "You’re up to date." : "\(release.tagName) is available."
        } catch {
            errorMessage = "Couldn’t check for updates. \(error.localizedDescription)"
        }
    }

    nonisolated private static func fetchPublicRelease() async throws -> SlipRelease {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.timeoutIntervalForRequest = 20
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/berkinduz/slip-menu-note-app/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Slip", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw UpdateError.unavailable
        }
        return try JSONDecoder().decode(SlipRelease.self, from: data)
    }

    private enum UpdateError: LocalizedError {
        case unavailable
        var errorDescription: String? { "The release service is unavailable. Try again later." }
    }
}
