import Foundation
import CryptoKit

public enum FolderSyncError: LocalizedError {
    case awaitingDownload
    public var errorDescription: String? { "Waiting for iCloud to download sync records." }
}

public struct FolderSyncResult: Sendable {
    public let library: NoteLibrary
    public let conflictCount: Int
}

/// Calls must be serialized by the owner; stateURL is private to this installation.
public struct FolderSyncEngine: Sendable {
    private let directory: URL
    private let stateURL: URL
    private let requestDownload: @Sendable (URL) throws -> Void
    private final class Cache: @unchecked Sendable {
        var library: NoteLibrary?
        var manifest: [String]?
        var offerManifest: [String]?
        var stateStamp: String?
        var idleOffer = false
    }
    private let cache = Cache()
    public init(directory: URL, stateURL: URL) {
        self.init(directory: directory, stateURL: stateURL, requestDownload: { try FileManager.default.startDownloadingUbiquitousItem(at: $0) })
    }
    init(directory: URL, stateURL: URL, requestDownload: @escaping @Sendable (URL) throws -> Void) {
        self.directory = directory; self.stateURL = stateURL; self.requestDownload = requestDownload
    }

    private struct Record: Codable, Equatable {
        var version = 1
        var id: UUID
        var entity: UUID
        var kind: String
        var vector: [String: Int]
        var note: Note?
        var folder: NoteFolder?
        var copies: [Record]? = nil
        var revisions: [Record]? = nil
    }
    private struct State: Codable {
        var version = 1
        var replica = UUID().uuidString
        var counter = 0
        var baseline = NoteLibrary()
        var captured: NoteLibrary?
        var records: [Record] = []
        var recoveries: [Record]? = nil
        var acknowledgedVectors: [String: [String: Int]] = [:]
        var pendingVectors: [String: [String: Int]] = [:]
        var offered: NoteLibrary?
        var offeredVectors: [String: [String: Int]] = [:]
    }
    private func key(_ kind: String, _ id: UUID) -> String { kind + ":" + id.uuidString }
    private func save(_ state: State) throws {
        try FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(state).write(to: stateURL, options: .atomic)
    }
    private func load() throws -> State {
        guard FileManager.default.fileExists(atPath: stateURL.path) else { return State() }
        let state = try JSONDecoder().decode(State.self, from: Data(contentsOf: stateURL))
        guard state.version == 1 else { throw CocoaError(.fileReadCorruptFile) }
        return state
    }
    private func joined(_ vectors: [[String: Int]]) -> [String: Int] {
        var result: [String: Int] = [:]
        for vector in vectors { for (replica, count) in vector { result[replica] = max(result[replica, default: 0], count) } }
        return result
    }
    private func dominates(_ a: Record, _ b: Record) -> Bool {
        a.entity == b.entity && a.kind == b.kind && a.id != b.id &&
        b.vector.allSatisfy { a.vector[$0.key, default: 0] >= $0.value } &&
        a.vector.contains { $0.value > b.vector[$0.key, default: 0] }
    }
    private func uniqueID(_ value: String) -> UUID {
        var bytes = Array(SHA256.hash(data: Data(value.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0f) | 0x50; bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (bytes[0],bytes[1],bytes[2],bytes[3],bytes[4],bytes[5],bytes[6],bytes[7],bytes[8],bytes[9],bytes[10],bytes[11],bytes[12],bytes[13],bytes[14],bytes[15]))
    }
    private func heads(_ records: [Record]) -> [Record] {
        let unique = Dictionary(records.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values
        let all = Array(unique)
        return all.filter { record in !all.contains { dominates($0, record) } }
    }
    private func fileFingerprint(_ url: URL) throws -> String {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        return url.lastPathComponent + ":" + String(describing: attrs[.size]) + ":" + String((attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0)
    }
    private func manifestMap() throws -> [String: String] {
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        return try Dictionary(uniqueKeysWithValues: urls.map { ($0.lastPathComponent, try fileFingerprint($0)) })
    }
    private func manifest() throws -> [String] { try manifestMap().values.sorted() }
    private func stamp() -> String? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: stateURL.path) else { return nil }
        return String(describing: attrs[.size]) + ":" + String((attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0)
    }
    public func synchronize(_ local: NoteLibrary) throws -> FolderSyncResult {
        if var library = cache.library, library.version == local.version,
           library.notes == local.notes, library.folders == local.folders, let previous = cache.manifest,
           cache.stateStamp == stamp(), (try? manifest()) == previous {
            library.selectedNoteID = local.selectedNoteID
            cache.library = library
            cache.idleOffer = true
            return FolderSyncResult(library: library, conflictCount: 0)
        }
        cache.idleOffer = false
        cache.library = nil
        cache.manifest = nil
        cache.offerManifest = nil
        cache.stateStamp = nil
        var state = try load()
        let before = state.captured ?? state.baseline
        func appendChange(_ kind: String, _ id: UUID, _ note: Note?, _ folder: NoteFolder?) {
            let k = key(kind, id)
            // Local pending changes depend on the last accepted state, never an unaccepted remote result.
            var vector = joined([state.acknowledgedVectors[k] ?? [:], state.pendingVectors[k] ?? [:]])
            state.counter += 1; vector[state.replica] = state.counter
            state.pendingVectors[k] = vector
            let inherited = state.records.filter { $0.kind == kind && $0.entity == id }.flatMap { $0.copies ?? [] } + (state.recoveries ?? []).filter { $0.entity == id && kind == "note" }.flatMap { $0.copies ?? [] }
            let copies = Array(Dictionary(inherited.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values).sorted { $0.id.uuidString < $1.id.uuidString }
            state.records.append(Record(id: UUID(), entity: id, kind: kind, vector: vector, note: note, folder: folder, copies: copies.isEmpty ? nil : copies))
        }
        let oldNotes = Dictionary(before.notes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let newNotes = Dictionary(local.notes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for id in Set(oldNotes.keys).union(newNotes.keys).sorted(by: { $0.uuidString < $1.uuidString }) where oldNotes[id] != newNotes[id] { appendChange("note", id, newNotes[id], nil) }
        let oldFolders = Dictionary(before.folders.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let newFolders = Dictionary(local.folders.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for id in Set(oldFolders.keys).union(newFolders.keys).sorted(by: { $0.uuidString < $1.uuidString }) where oldFolders[id] != newFolders[id] { appendChange("folder", id, nil, newFolders[id]) }
        state.captured = local
        try save(state) // Pending revisions survive any subsequent folder error.
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        // Never certify a file that arrived after this snapshot without processing it.
        var processed = try manifestMap()
        let entries = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey])
        let names = Set(entries.map(\.lastPathComponent))
        processed = processed.filter { names.contains($0.key) }
        var downloads: Set<URL> = []
        for url in entries {
            let name = url.lastPathComponent
            if name.hasPrefix("."), name.hasSuffix(".json.icloud") {
                let id = String(name.dropFirst().dropLast(".json.icloud".count))
                if UUID(uuidString: id) != nil {
                    let target = directory.appendingPathComponent(id + ".json")
                    downloads.insert(target)
                }
            }
            if url.pathExtension == "json", UUID(uuidString: url.deletingPathExtension().lastPathComponent) != nil {
                let values = try url.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey])
                if values.isUbiquitousItem == true && values.ubiquitousItemDownloadingStatus == .notDownloaded {
                    downloads.insert(url)
                }
            }
        }
        var downloadError: (any Error)?
        for target in downloads.sorted(by: { $0.path < $1.path }) {
            do { try requestDownload(target) } catch { if downloadError == nil { downloadError = error } }
        }
        if let downloadError { throw downloadError }
        if !downloads.isEmpty { throw FolderSyncError.awaitingDownload }
        let urls = entries.filter { $0.pathExtension == "json" }
        func valid(_ record: Record) -> Bool {
            guard record.version == 1, !record.vector.isEmpty, record.vector.values.allSatisfy({ $0 > 0 }) else { return false }
            let payloadValid = (record.kind == "note" && record.folder == nil && (record.note == nil || record.note?.id == record.entity)) || (record.kind == "folder" && record.note == nil && (record.folder == nil || record.folder?.id == record.entity))
            guard payloadValid, record.revisions == nil else { return false }
            return (record.copies ?? []).allSatisfy { $0.version == 1 && $0.kind == "note" && $0.note?.id == $0.entity && $0.folder == nil && $0.copies == nil && $0.revisions == nil && !$0.vector.isEmpty && $0.vector.values.allSatisfy({ $0 > 0 }) }
        }
        for url in urls {
            guard UUID(uuidString: url.deletingPathExtension().lastPathComponent) != nil else { continue }
            let data = try Data(contentsOf: url)
            guard let record = try? JSONDecoder().decode(Record.self, from: data),
                  url.deletingPathExtension().lastPathComponent.lowercased() == record.id.uuidString.lowercased() else { throw CocoaError(.fileReadCorruptFile) }
            if record.kind == "recovery" {
                guard record.version == 1, record.note == nil, record.folder == nil, !record.vector.isEmpty, record.vector.values.allSatisfy({ $0 > 0 }),
                      let revisions = record.revisions, !revisions.isEmpty, revisions.allSatisfy({ valid($0) && $0.kind == "note" && $0.entity == record.entity }),
                      (record.copies ?? []).allSatisfy({ valid($0) && $0.kind == "note" && $0.note != nil && $0.copies == nil }) else { throw CocoaError(.fileReadCorruptFile) }
                state.recoveries = (state.recoveries ?? []) + [record]
                state.records.append(contentsOf: revisions)
            } else {
                guard valid(record) else { throw CocoaError(.fileReadCorruptFile) }
                state.records.append(record)
            }
            state.records.append(contentsOf: record.copies ?? [])
        }
        state.recoveries = Array(Dictionary((state.recoveries ?? []).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values)
        state.records = heads(state.records)
        let groups = Dictionary(grouping: state.records, by: { key($0.kind, $0.entity) })
        var generated: [Record] = []
        var conflictCount = 0
        func winner(_ group: [Record]) -> Record {
            let sorted = group.sorted { $0.id.uuidString < $1.id.uuidString }
            return sorted.first(where: { $0.kind == "note" ? $0.note == nil : $0.folder == nil }) ?? sorted[0]
        }
        for group in groups.values where group.count > 1 && group[0].kind == "note" {
            let ordered = group.sorted { $0.id.uuidString < $1.id.uuidString }
            let selected = winner(ordered)
            var copies: [Record] = ordered.flatMap { $0.copies ?? [] }
            for loser in ordered where loser.id != selected.id {
                guard let note = loser.note else { continue }
                if let winning = selected.note, note.title == winning.title, note.body == winning.body,
                   note.tags == winning.tags, note.folderID == winning.folderID, note.isPinned == winning.isPinned,
                   (note.deletedAt == nil) == (winning.deletedAt == nil) { continue }
                let copyID = uniqueID("conflict:" + loser.id.uuidString)
                let copy = Note(id: copyID, title: (note.title.isEmpty ? note.displayTitle : note.title) + " (Conflict)", body: note.body, tags: note.tags, folderID: note.folderID, isPinned: note.isPinned, createdAt: note.createdAt, updatedAt: note.updatedAt, deletedAt: note.deletedAt)
                let item = Record(id: uniqueID("copy-record:" + loser.id.uuidString), entity: copyID, kind: "note", vector: loser.vector, note: copy, folder: nil)
                copies.append(item)
                if !state.records.contains(where: { $0.entity == copyID }) { conflictCount += 1 }
            }
            copies = Array(Dictionary(copies.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values).sorted { $0.id.uuidString < $1.id.uuidString }
            if !copies.isEmpty {
                let identity = ordered.map { $0.id.uuidString }.joined(separator: ":") + ":" + copies.map { $0.id.uuidString }.joined(separator: ":")
                let envelope = Record(id: uniqueID("recovery:" + identity), entity: selected.entity, kind: "recovery", vector: joined(ordered.map(\.vector)), note: nil, folder: nil, copies: copies, revisions: ordered)
                if !(state.recoveries ?? []).contains(where: { $0.id == envelope.id }) { state.recoveries = (state.recoveries ?? []) + [envelope] }
                generated.append(contentsOf: copies)
            }
        }
        state.records = heads(state.records + generated)
        let finalGroups = Dictionary(grouping: state.records, by: { key($0.kind, $0.entity) })
        let selected = finalGroups.values.map(winner)
        let notes = selected.compactMap(\.note).sorted { $0.id.uuidString < $1.id.uuidString }
        var folders = selected.compactMap(\.folder).sorted { $0.id.uuidString < $1.id.uuidString }
        let deletedFolders = Set(selected.filter { $0.kind == "folder" && $0.folder == nil }.map(\.entity))
        for index in folders.indices where folders[index].parentID.map(deletedFolders.contains) == true { folders[index].parentID = nil }
        while true {
            let byID = Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0) })
            var detached: UUID?
            for start in byID.keys.sorted(by: { $0.uuidString < $1.uuidString }) {
                var path: [UUID] = []
                var current: UUID? = start
                while let id = current, let folder = byID[id] {
                    if let index = path.firstIndex(of: id) {
                        detached = path[index...].min { $0.uuidString < $1.uuidString }
                        break
                    }
                    path.append(id); current = folder.parentID
                }
                if detached != nil { break }
            }
            guard let id = detached, let index = folders.firstIndex(where: { $0.id == id }) else { break }
            folders[index].parentID = nil
        }
        try save(state)
        for record in state.records + (state.recoveries ?? []) {
            let url = directory.appendingPathComponent(record.id.uuidString + ".json")
            if FileManager.default.fileExists(atPath: url.path) {
                guard let existing = try? JSONDecoder().decode(Record.self, from: Data(contentsOf: url)), existing == record else {
                    throw CocoaError(.fileWriteFileExists)
                }
            } else {
                try JSONEncoder().encode(record).write(to: url, options: .atomic)
                processed[url.lastPathComponent] = try fileFingerprint(url)
            }
        }
        // Never remove records we could not decode, or records not dominated by a published successor.
        for url in urls {
            guard let data = try? Data(contentsOf: url), let old = try? JSONDecoder().decode(Record.self, from: data), old.version == 1,
                  url.deletingPathExtension().lastPathComponent.lowercased() == old.id.uuidString.lowercased(),
                  state.records.contains(where: { dominates($0, old) }) else { continue }
            try FileManager.default.removeItem(at: url)
            processed.removeValue(forKey: url.lastPathComponent)
        }
        var result = NoteLibrary(notes: notes, folders: folders, selectedNoteID: local.selectedNoteID)
        result.version = local.version
        state.offered = result
        state.offeredVectors = finalGroups.mapValues { joined($0.map(\.vector)) }
        try save(state)
        cache.offerManifest = processed.values.sorted()
        return FolderSyncResult(library: result, conflictCount: conflictCount)
    }
    public func acknowledge(_ library: NoteLibrary) throws {
        if cache.idleOffer && cache.library == library { cache.idleOffer = false; return }
        var state = try load()
        guard state.offered == library else { throw CocoaError(.fileWriteUnknown) }
        state.baseline = library; state.captured = nil; state.acknowledgedVectors = state.offeredVectors; state.pendingVectors = [:]
        state.offered = nil; state.offeredVectors = [:]
        try save(state)
        if let processed = cache.offerManifest, (try? manifest()) == processed {
            cache.library = library
            cache.manifest = processed
            cache.stateStamp = stamp()
        } else {
            cache.library = nil
            cache.manifest = nil
            cache.stateStamp = nil
        }
        cache.offerManifest = nil
        cache.idleOffer = false
    }
}
