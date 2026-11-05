import Foundation

public struct LibraryBackup: Sendable {
    public let url: URL
    public let createdAt: Date
}

public struct LibraryBackupStore: Sendable {
    public let directory: URL
    public init(directory: URL) { self.directory = directory }
    @discardableResult
    public func create(_ library: NoteLibrary, now: Date = .now) throws -> URL {
        let data = try LibraryTransfer.archive(library, createdAt: now)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(now.timeIntervalSince1970)-\(UUID().uuidString).slipbackup")
        try data.write(to: url, options: .atomic)
        for backup in try list().dropFirst(30) {
            try FileManager.default.removeItem(at: backup.url)
        }
        return url
    }

    /// Only recoverable Slip snapshots appear in the restore list.
    public func list() throws -> [LibraryBackup] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "slipbackup" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url),
                      let archive = try? LibraryTransfer.decodedArchive(data) else { return nil }
                return LibraryBackup(url: directory.appendingPathComponent(url.lastPathComponent), createdAt: archive.createdAt)
            }
            .sorted {
                $0.createdAt == $1.createdAt ? $0.url.lastPathComponent < $1.url.lastPathComponent : $0.createdAt > $1.createdAt
            }
    }

    public func load(_ url: URL) throws -> NoteLibrary {
        try LibraryTransfer.decodeArchive(Data(contentsOf: url))
    }

    fileprivate func inventory() throws -> [BackupInventoryEntry] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey]
        return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys))
            .filter { $0.pathExtension == "slipbackup" }
            .map { url in
                let values = try url.resourceValues(forKeys: keys)
                return BackupInventoryEntry(name: url.lastPathComponent, modifiedAt: values.contentModificationDate, size: values.fileSize)
            }
            .sorted { $0.name < $1.name }
    }
}

fileprivate struct BackupInventoryEntry: Equatable {
    let name: String
    let modifiedAt: Date?
    let size: Int?
}

/// Repository copies share this cache; all cached state is protected by the lock.
final class LibraryBackupSchedule: @unchecked Sendable {
    private let lock = NSLock()
    private var verifiedInventory: [BackupInventoryEntry]?
    private var newestCreatedAt: Date?

    func needsSnapshot(in store: LibraryBackupStore, now: Date) throws -> Bool {
        try lock.withLock {
            let inventory = try store.inventory()
            let due = newestCreatedAt.map { now.timeIntervalSince($0) >= 30 * 60 } ?? true
            if inventory != verifiedInventory || due {
                newestCreatedAt = try store.list().first?.createdAt
                verifiedInventory = inventory
            }
            return newestCreatedAt.map { now.timeIntervalSince($0) >= 30 * 60 } ?? true
        }
    }
}
