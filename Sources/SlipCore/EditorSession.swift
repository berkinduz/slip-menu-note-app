import Foundation

public struct EditorPosition: Codable, Equatable, Sendable {
    public var selection: NSRange
    public var scrollOffset: Double
    public init(selection: NSRange, scrollOffset: Double) {
        self.selection = selection
        self.scrollOffset = scrollOffset
    }
}

@MainActor public final class EditorSessionStore {
    private struct State: Codable {
        var positions: [UUID: EditorPosition] = [:]
        var panelWidth: Double?
        var panelHeight: Double?
    }
    private let url: URL
    private var pending: Task<Void, Never>?
    public var positions: [UUID: EditorPosition] { didSet { save() } }
    public var panelWidth: Double? { didSet { save() } }
    public var panelHeight: Double? { didSet { save() } }

    public init(directory: URL) {
        url = directory.appendingPathComponent("editor-session.json")
        let state = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(State.self, from: $0) } ?? State()
        positions = state.positions
        panelWidth = state.panelWidth
        panelHeight = state.panelHeight
    }
    public func save() {
        pending?.cancel()
        pending = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.flush()
        }
    }
    public func flush() {
        pending?.cancel()
        pending = nil
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(State(positions: positions, panelWidth: panelWidth, panelHeight: panelHeight))
            try data.write(to: url, options: .atomic)
        } catch { NSLog("Could not save editor session: %@", error.localizedDescription) }
    }
}
