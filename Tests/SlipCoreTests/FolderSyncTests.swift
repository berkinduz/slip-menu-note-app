import Foundation
import Testing
@testable import SlipCore

@Test func folderSyncReplicasConvergeAndPreserveConcurrentEdits() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let a = FolderSyncEngine(directory: root.appendingPathComponent("shared"), stateURL: root.appendingPathComponent("a.json"))
    let b = FolderSyncEngine(directory: root.appendingPathComponent("shared"), stateURL: root.appendingPathComponent("b.json"))
    let note = Note(title: "Note", body: "initial")
    var left = NoteLibrary(notes: [note], selectedNoteID: note.id)
    left = try a.synchronize(left).library; try a.acknowledge(left)
    var right = try b.synchronize(NoteLibrary()).library; try b.acknowledge(right)
    left.notes[0].body = "left"; right.notes[0].body = "right"
    left = try a.synchronize(left).library; try a.acknowledge(left)
    right = try b.synchronize(right).library; try b.acknowledge(right)
    left = try a.synchronize(left).library; try a.acknowledge(left)
    right = try b.synchronize(right).library; try b.acknowledge(right)
    #expect(Set(left.notes.map(\.body)) == ["left", "right"])
    #expect(left.notes.sorted { $0.id.uuidString < $1.id.uuidString } == right.notes.sorted { $0.id.uuidString < $1.id.uuidString })
    #expect(left.selectedNoteID == note.id)
}

@Test func folderSyncDeletionVersusEditAndDeletedConflictDoesNotReturn() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let shared = root.appendingPathComponent("shared")
    let a = FolderSyncEngine(directory: shared, stateURL: root.appendingPathComponent("a"))
    let b = FolderSyncEngine(directory: shared, stateURL: root.appendingPathComponent("b"))
    let note = Note(title: "Original", body: "before")
    var left = try a.synchronize(NoteLibrary(notes: [note])).library; try a.acknowledge(left)
    var right = try b.synchronize(NoteLibrary()).library; try b.acknowledge(right)
    left.notes.removeAll(); right.notes[0].body = "offline edit"
    left = try a.synchronize(left).library; try a.acknowledge(left)
    right = try b.synchronize(right).library; try b.acknowledge(right)
    #expect(right.notes.count == 1)
    #expect(right.notes.first?.body == "offline edit")
    #expect(right.notes.first?.id != note.id)
    left = try a.synchronize(left).library; try a.acknowledge(left)
    #expect(left.notes == right.notes)
    right.notes.removeAll()
    right = try b.synchronize(right).library; try b.acknowledge(right)
    left = try a.synchronize(left).library; try a.acknowledge(left)
    right = try b.synchronize(right).library; try b.acknowledge(right)
    #expect(left.notes.isEmpty && right.notes.isEmpty)
}

@Test func folderSyncRetriesPendingAndIgnoresMalformedFiles() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let shared = root.appendingPathComponent("shared")
    try Data("not a directory".utf8).write(to: shared)
    let state = root.appendingPathComponent("state")
    let note = Note(body: "pending")
    let engine = FolderSyncEngine(directory: shared, stateURL: state)
    #expect(throws: (any Error).self) { try engine.synchronize(NoteLibrary(notes: [note])) }
    try FileManager.default.removeItem(at: shared)
    try FileManager.default.createDirectory(at: shared, withIntermediateDirectories: true)
    try Data("{".utf8).write(to: shared.appendingPathComponent("bad.json"))
    let restarted = FolderSyncEngine(directory: shared, stateURL: state)
    let result = try restarted.synchronize(NoteLibrary(notes: [note]))
    #expect(result.library.notes == [note])
    try restarted.acknowledge(result.library)
    #expect(FileManager.default.fileExists(atPath: shared.appendingPathComponent("bad.json").path))
}

@Test func folderSyncFoldersAndBoundedHistory() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let shared = root.appendingPathComponent("shared")
    let engine = FolderSyncEngine(directory: shared, stateURL: root.appendingPathComponent("state"))
    var folder = NoteFolder(name: "First")
    var library = NoteLibrary(notes: [Note(body: "0", folderID: folder.id)], folders: [folder])
    for i in 0..<30 {
        library.notes[0].body = "\(i)"
        folder.name = "Folder \(i)"; library.folders = [folder]
        library = try engine.synchronize(library).library; try engine.acknowledge(library)
    }
    #expect(try FileManager.default.contentsOfDirectory(atPath: shared.path).count <= 2)
    library.folders = []; library.notes[0].folderID = nil
    library = try engine.synchronize(library).library; try engine.acknowledge(library)
    let other = FolderSyncEngine(directory: shared, stateURL: root.appendingPathComponent("other"))
    let received = try other.synchronize(NoteLibrary()).library
    #expect(received.folders.isEmpty && received.notes[0].folderID == nil)
}

@Test func folderSyncRejectedSnapshotIsRetryable() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let shared = root.appendingPathComponent("shared")
    let a = FolderSyncEngine(directory: shared, stateURL: root.appendingPathComponent("a"))
    let b = FolderSyncEngine(directory: shared, stateURL: root.appendingPathComponent("b"))
    let note = Note(body: "base")
    var left = try a.synchronize(NoteLibrary(notes: [note])).library; try a.acknowledge(left)
    var right = try b.synchronize(NoteLibrary()).library; try b.acknowledge(right)
    right.notes[0].body = "remote"; right = try b.synchronize(right).library; try b.acknowledge(right)
    let rejected = try a.synchronize(left)
    #expect(rejected.library.notes[0].body == "remote")
    left.notes[0].body = "new local"
    let retried = try a.synchronize(left)
    #expect(Set(retried.library.notes.map(\.body)) == ["remote", "new local"])
    #expect(throws: (any Error).self) { try a.acknowledge(rejected.library) }
    try a.acknowledge(retried.library)
    let repeated = try a.synchronize(retried.library)
    #expect(repeated.library == retried.library)
}

@Test func folderSyncFolderChangeAndDuplicateRecord() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let first = root.appendingPathComponent("first")
    let second = root.appendingPathComponent("second")
    let state = root.appendingPathComponent("state")
    let note = Note(body: "note")
    let initial = FolderSyncEngine(directory: first, stateURL: state)
    var local = try initial.synchronize(NoteLibrary(notes: [note])).library; try initial.acknowledge(local)
    local = try initial.synchronize(local).library; try initial.acknowledge(local)
    #expect(local.notes == [note])
    let moved = FolderSyncEngine(directory: second, stateURL: state)
    local = try moved.synchronize(local).library; try moved.acknowledge(local)
    let another = FolderSyncEngine(directory: second, stateURL: root.appendingPathComponent("other"))
    #expect(try another.synchronize(NoteLibrary()).library.notes == [note])
}

@Test func folderSyncPreservesConcurrentMetadata() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let a = FolderSyncEngine(directory: root.appendingPathComponent("s"), stateURL: root.appendingPathComponent("a"))
    let b = FolderSyncEngine(directory: root.appendingPathComponent("s"), stateURL: root.appendingPathComponent("b"))
    let note = Note(title: "base", body: "same")
    var left = try a.synchronize(NoteLibrary(notes: [note])).library; try a.acknowledge(left)
    var right = try b.synchronize(NoteLibrary()).library; try b.acknowledge(right)
    left.notes[0].title = "left"; right.notes[0].tags = ["right"]
    left = try a.synchronize(left).library; try a.acknowledge(left)
    right = try b.synchronize(right).library
    #expect(right.notes.count == 2)
    #expect(right.notes.contains { $0.title == "left" || $0.title == "left (Conflict)" })
    #expect(right.notes.contains { $0.tags == ["right"] })
}

@Test func folderSyncRepairsConcurrentFolderCycle() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let a = FolderSyncEngine(directory: root.appendingPathComponent("s"), stateURL: root.appendingPathComponent("a"))
    let b = FolderSyncEngine(directory: root.appendingPathComponent("s"), stateURL: root.appendingPathComponent("b"))
    let one = NoteFolder(name: "one"), two = NoteFolder(name: "two")
    var left = try a.synchronize(NoteLibrary(folders: [one, two])).library; try a.acknowledge(left)
    var right = try b.synchronize(NoteLibrary()).library; try b.acknowledge(right)
    left.folders[left.folders.firstIndex { $0.id == one.id }!].parentID = two.id
    right.folders[right.folders.firstIndex { $0.id == two.id }!].parentID = one.id
    left = try a.synchronize(left).library; try a.acknowledge(left)
    right = try b.synchronize(right).library; try b.acknowledge(right)
    left = try a.synchronize(left).library; try a.acknowledge(left)
    #expect(left.folders == right.folders)
    #expect(left.folders.count == 2)
    #expect(left.folders.contains { $0.parentID == nil })
    for folder in left.folders { _ = left.folderPath(folder.id) }
}

@Test func folderSyncRejectsMalformedNamedRecord() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let shared = root.appendingPathComponent("s")
    try FileManager.default.createDirectory(at: shared, withIntermediateDirectories: true)
    let invalid = shared.appendingPathComponent(UUID().uuidString + ".json")
    try Data("{".utf8).write(to: invalid)
    let engine = FolderSyncEngine(directory: shared, stateURL: root.appendingPathComponent("state"))
    let note = Note(body: "keep")
    #expect(throws: (any Error).self) { try engine.synchronize(NoteLibrary(notes: [note])) }
    try FileManager.default.removeItem(at: invalid)
    #expect(try engine.synchronize(NoteLibrary(notes: [note])).library.notes == [note])
}

@Test func folderSyncResolutionSurvivesPartialDeliveryAndLaterEdit() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let full = root.appendingPathComponent("full"), partial = root.appendingPathComponent("partial")
    let a = FolderSyncEngine(directory: full, stateURL: root.appendingPathComponent("a"))
    let b = FolderSyncEngine(directory: full, stateURL: root.appendingPathComponent("b"))
    let note = Note(body: "base")
    var left = try a.synchronize(NoteLibrary(notes: [note])).library; try a.acknowledge(left)
    var right = try b.synchronize(NoteLibrary()).library; try b.acknowledge(right)
    left.notes[0].body = "left"; right.notes[0].body = "right"
    left = try a.synchronize(left).library; try a.acknowledge(left)
    right = try b.synchronize(right).library; try b.acknowledge(right)
    try FileManager.default.createDirectory(at: partial, withIntermediateDirectories: true)
    let originalRecord = try #require(FileManager.default.contentsOfDirectory(at: full, includingPropertiesForKeys: nil).first { url in
        guard let data = try? Data(contentsOf: url), let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], let entity = object["entity"] as? String else { return false }
        return entity == note.id.uuidString && object["kind"] as? String == "recovery"
    })
    try FileManager.default.copyItem(at: originalRecord, to: partial.appendingPathComponent(originalRecord.lastPathComponent))
    let c = FolderSyncEngine(directory: partial, stateURL: root.appendingPathComponent("c"))
    var recovered = try c.synchronize(NoteLibrary()).library; try c.acknowledge(recovered)
    #expect(Set(recovered.notes.map(\.body)) == ["left", "right"])
    let index = try #require(recovered.notes.firstIndex { $0.id == note.id })
    recovered.notes[index].title = "subsequent"
    recovered = try c.synchronize(recovered).library; try c.acknowledge(recovered)
    // Simulate the copy record being delayed even after the successor arrives.
    for url in try FileManager.default.contentsOfDirectory(at: partial, includingPropertiesForKeys: nil) {
        let object = try #require((try JSONSerialization.jsonObject(with: Data(contentsOf: url))) as? [String: Any])
        if (object["entity"] as? String) != note.id.uuidString { try FileManager.default.removeItem(at: url) }
    }
    let d = FolderSyncEngine(directory: partial, stateURL: root.appendingPathComponent("d"))
    let later = try d.synchronize(NoteLibrary()).library
    #expect(Set(later.notes.map(\.body)) == ["left", "right"])
}

@Test func folderSyncPendingParentAndDeletedParent() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let shared = root.appendingPathComponent("shared")
    let writer = FolderSyncEngine(directory: shared, stateURL: root.appendingPathComponent("writer"))
    let parent = NoteFolder(name: "parent")
    let child = NoteFolder(name: "child", parentID: parent.id)
    var library = try writer.synchronize(NoteLibrary(folders: [parent, child])).library; try writer.acknowledge(library)
    let parentRecord = try #require(FileManager.default.contentsOfDirectory(at: shared, includingPropertiesForKeys: nil).first { url in
        guard let data = try? Data(contentsOf: url), let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return false }
        return object["entity"] as? String == parent.id.uuidString
    })
    let savedParent = try Data(contentsOf: parentRecord)
    try FileManager.default.removeItem(at: parentRecord)
    let other = FolderSyncEngine(directory: shared, stateURL: root.appendingPathComponent("other"))
    var received = try other.synchronize(NoteLibrary()).library; try other.acknowledge(received)
    #expect(received.folders.first?.parentID == parent.id)
    try savedParent.write(to: parentRecord)
    received = try other.synchronize(received).library; try other.acknowledge(received)
    #expect(received.folders.first { $0.id == child.id }?.parentID == parent.id)
    library.folders.removeAll { $0.id == parent.id }
    library = try writer.synchronize(library).library; try writer.acknowledge(library)
    received = try other.synchronize(received).library; try other.acknowledge(received)
    #expect(received.folders.first { $0.id == child.id }?.parentID == nil)
}

@Test func folderSyncTimestampOnlyChangesDoNotMakeCopies() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let a = FolderSyncEngine(directory: root.appendingPathComponent("s"), stateURL: root.appendingPathComponent("a"))
    let b = FolderSyncEngine(directory: root.appendingPathComponent("s"), stateURL: root.appendingPathComponent("b"))
    let note = Note(body: "same")
    var left = try a.synchronize(NoteLibrary(notes: [note])).library; try a.acknowledge(left)
    var right = try b.synchronize(NoteLibrary()).library; try b.acknowledge(right)
    left.notes[0].updatedAt = Date(timeIntervalSince1970: 1)
    right.notes[0].updatedAt = Date(timeIntervalSince1970: 2)
    left = try a.synchronize(left).library; try a.acknowledge(left)
    right = try b.synchronize(right).library
    #expect(right.notes.count == 1)
}

@Test func folderSyncOutOfOrderReplicaRevisionsConverge() throws {
    let fm = FileManager.default, root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? fm.removeItem(at: root) }
    let da = root.appendingPathComponent("a"), db = root.appendingPathComponent("b")
    let a = FolderSyncEngine(directory: da, stateURL: root.appendingPathComponent("sa")), b = FolderSyncEngine(directory: db, stateURL: root.appendingPathComponent("sb"))
    func sync(_ engine: FolderSyncEngine, _ local: NoteLibrary) throws -> NoteLibrary { let result = try engine.synchronize(local).library; try engine.acknowledge(result); return result }
    func snapshot(_ dir: URL) throws -> [String: Data] { try Dictionary(uniqueKeysWithValues: fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil).map { ($0.lastPathComponent, try Data(contentsOf: $0)) }) }
    func deliver(_ batch: [String: Data], _ dir: URL) throws { try fm.createDirectory(at: dir, withIntermediateDirectories: true); for (name, data) in batch { try data.write(to: dir.appendingPathComponent(name)) } }
    let note = Note(body: "base")
    var left = try sync(a, NoteLibrary(notes: [note])); try deliver(snapshot(da), db)
    var right = try sync(b, NoteLibrary())
    left.notes[0].body = "a1"; left = try sync(a, left); let a1 = try snapshot(da)
    right.notes[0].body = "b1"; right = try sync(b, right); let b1 = try snapshot(db)
    left.notes[0].body = "a2"; left = try sync(a, left); let a2 = try snapshot(da)
    right.notes[0].body = "b2"; right = try sync(b, right); let b2 = try snapshot(db)
    try deliver(b1, da); left = try sync(a, left)
    try deliver(a1, db); right = try sync(b, right)
    try deliver(b2, da); left = try sync(a, left)
    try deliver(a2, db); right = try sync(b, right)
    let endA = try snapshot(da), endB = try snapshot(db)
    try deliver(endB, da); try deliver(endA, db)
    left = try sync(a, left); right = try sync(b, right)
    try deliver(snapshot(da), db); try deliver(snapshot(db), da)
    left = try sync(a, left); right = try sync(b, right)
    #expect(left.notes == right.notes)
    #expect(Set(left.notes.map(\.body)).isSuperset(of: ["a2", "b2"]))
}

@Test func folderSyncDelayedChildChangeSurvivesParentTombstone() throws {
    let fm = FileManager.default, root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? fm.removeItem(at: root) }
    let da = root.appendingPathComponent("a"), db = root.appendingPathComponent("b")
    let a = FolderSyncEngine(directory: da, stateURL: root.appendingPathComponent("sa")), b = FolderSyncEngine(directory: db, stateURL: root.appendingPathComponent("sb"))
    func sync(_ e: FolderSyncEngine, _ lib: NoteLibrary) throws -> NoteLibrary { let result = try e.synchronize(lib).library; try e.acknowledge(result); return result }
    func deliver(_ predicate: ([String: Any]) -> Bool) throws { try fm.createDirectory(at: db, withIntermediateDirectories: true); for url in try fm.contentsOfDirectory(at: da, includingPropertiesForKeys: nil) { let data = try Data(contentsOf: url); let obj = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any]); if predicate(obj) { try data.write(to: db.appendingPathComponent(url.lastPathComponent)) } } }
    let old = NoteFolder(name: "old"), target = NoteFolder(name: "new"), child = NoteFolder(name: "child", parentID: old.id)
    var left = try sync(a, NoteLibrary(folders: [old, target, child])); try deliver { _ in true }
    var right = try sync(b, NoteLibrary())
    let index = try #require(left.folders.firstIndex { $0.id == child.id }); left.folders[index].name = "renamed"; left.folders[index].parentID = target.id
    left = try sync(a, left); left.folders.removeAll { $0.id == old.id }; left = try sync(a, left)
    try deliver { $0["entity"] as? String == old.id.uuidString }; right = try sync(b, right)
    try deliver { _ in true }; right = try sync(b, right)
    let found = try #require(right.folders.first { $0.id == child.id })
    #expect(found.name == "renamed" && found.parentID == target.id)
}

@Test func folderSyncIdleDoesNotRewriteState() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let state = root.appendingPathComponent("state"), engine = FolderSyncEngine(directory: root.appendingPathComponent("s"), stateURL: state)
    let result = try engine.synchronize(NoteLibrary(notes: [Note(body: "hello")])).library; try engine.acknowledge(result)
    let before = try FileManager.default.attributesOfItem(atPath: state.path)[.modificationDate] as? Date
    let idle = try engine.synchronize(result).library; try engine.acknowledge(idle)
    let after = try FileManager.default.attributesOfItem(atPath: state.path)[.modificationDate] as? Date
    #expect(before == after)
}

@Test func folderSyncCloudPlaceholderIsPending() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let dir = root.appendingPathComponent("s"); try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try Data().write(to: dir.appendingPathComponent("." + UUID().uuidString + ".json.icloud"))
    let e = FolderSyncEngine(directory: dir, stateURL: root.appendingPathComponent("state"), requestDownload: { _ in })
    #expect(throws: (any Error).self) { try e.synchronize(NoteLibrary()) }
}

@Test func folderSyncIdleCacheNoticesMissingOrChangedRecord() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let dir = root.appendingPathComponent("s"), state = root.appendingPathComponent("state")
    let engine = FolderSyncEngine(directory: dir, stateURL: state)
    let note = Note(body: "body")
    let first = try engine.synchronize(NoteLibrary(notes: [note])).library; try engine.acknowledge(first)
    let file = try #require(FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil).first)
    try FileManager.default.removeItem(at: file)
    let restored = try engine.synchronize(first).library; try engine.acknowledge(restored)
    #expect(FileManager.default.fileExists(atPath: file.path))
    try Data("broken".utf8).write(to: file)
    #expect(throws: (any Error).self) { try engine.synchronize(restored) }
}

@Test func folderSyncSelectionOnlyDoesNotRewriteStateOrRecords() throws {
    let fm = FileManager.default, root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? fm.removeItem(at: root) }
    let dir = root.appendingPathComponent("s"), state = root.appendingPathComponent("state")
    let engine = FolderSyncEngine(directory: dir, stateURL: state)
    let first = Note(body: "first"), second = Note(body: "second")
    var library = try engine.synchronize(NoteLibrary(notes: [first, second], selectedNoteID: first.id)).library
    try engine.acknowledge(library)
    func timestamps() throws -> [String: Date] {
        let urls = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) + [state]
        return try Dictionary(uniqueKeysWithValues: urls.map { url in
            (url.path, try #require(fm.attributesOfItem(atPath: url.path)[.modificationDate] as? Date))
        })
    }
    let before = try timestamps()
    library.selectedNoteID = second.id
    let offered = try engine.synchronize(library).library
    #expect(offered.selectedNoteID == second.id)
    try engine.acknowledge(offered)
    #expect(try timestamps() == before)
}

@Test func folderSyncImportsRecordArrivingBeforeAcknowledge() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let shared = root.appendingPathComponent("s")
    let a = FolderSyncEngine(directory: shared, stateURL: root.appendingPathComponent("a"))
    let b = FolderSyncEngine(directory: shared, stateURL: root.appendingPathComponent("b"))
    let offered = try a.synchronize(NoteLibrary()).library
    let note = Note(body: "arrived before acknowledge")
    let published = try b.synchronize(NoteLibrary(notes: [note])).library; try b.acknowledge(published)
    try a.acknowledge(offered)
    let received = try a.synchronize(offered).library
    #expect(received.notes == [note])
}

private final class FolderSyncDownloadCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [URL] = []
    func append(_ url: URL) { lock.lock(); defer { lock.unlock() }; values.append(url) }
    func snapshot() -> [URL] { lock.lock(); defer { lock.unlock() }; return values }
}
private enum FolderSyncDownloadTestError: Error { case denied }

@Test func folderSyncRequestsEveryPlaceholderAndPreservesErrors() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let dir = root.appendingPathComponent("s"); try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let ids = [UUID(), UUID(), UUID()]
    for id in ids { try Data().write(to: dir.appendingPathComponent("." + id.uuidString + ".json.icloud")) }
    let capture = FolderSyncDownloadCapture()
    let engine = FolderSyncEngine(directory: dir, stateURL: root.appendingPathComponent("state"), requestDownload: { url in
        capture.append(url)
        if url.lastPathComponent == ids[0].uuidString + ".json" { throw FolderSyncDownloadTestError.denied }
    })
    #expect(throws: FolderSyncDownloadTestError.denied) { try engine.synchronize(NoteLibrary()) }
    #expect(Set(capture.snapshot().map(\.lastPathComponent)) == Set(ids.map { $0.uuidString + ".json" }))
}

@Test func folderSyncRequestsEveryPlaceholderWhenWaiting() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let dir = root.appendingPathComponent("s"); try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let ids = [UUID(), UUID(), UUID()]
    for id in ids { try Data().write(to: dir.appendingPathComponent("." + id.uuidString + ".json.icloud")) }
    let capture = FolderSyncDownloadCapture()
    let engine = FolderSyncEngine(directory: dir, stateURL: root.appendingPathComponent("state"), requestDownload: { capture.append($0) })
    #expect(throws: FolderSyncError.self) { try engine.synchronize(NoteLibrary()) }
    #expect(Set(capture.snapshot().map(\.lastPathComponent)) == Set(ids.map { $0.uuidString + ".json" }))
}
