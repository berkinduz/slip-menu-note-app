import AppKit
import SlipCore
import UniformTypeIdentifiers

extension Workspace {
    func chooseBackupToRestore() {
        let picker = NSOpenPanel()
        picker.title = "Restore a Slip backup"
        picker.message = "Choose a Slip backup to replace your current library. A safety copy is kept first."
        picker.allowedContentTypes = [UTType(filenameExtension: "slipbackup") ?? .json]
        guard picker.runModal() == .OK, let url = picker.url else { return }
        do {
            _ = try LibraryTransfer.decodeArchive(Data(contentsOf: url))
            backupToRestore = url
        } catch { operationError = "Couldn’t read this backup. \(error.localizedDescription)" }
    }

    func refreshBackups() {
        do { backups = try backupStore.list() }
        catch { operationError = "Couldn’t read backups. \(error.localizedDescription)" }
    }

    func createBackup() {
        do {
            _ = try backupStore.create(notebook.library)
            refreshBackups()
            message("Backup created")
        } catch { operationError = "Couldn’t create a backup. \(error.localizedDescription)" }
    }

    func restoreBackup(_ url: URL) {
        do {
            let library = try backupStore.load(url)
            try notebook.restoreLibrary(library)
            query = ""
            changeFilter(.all)
            searchRevealRequest = nil
            refreshBackups()
            message("Backup restored")
            Task { await sync.synchronize() }
        } catch { operationError = "Couldn’t restore this backup. \(error.localizedDescription)" }
    }

    func exportBackup() {
        let picker = NSSavePanel()
        picker.title = "Export Slip backup"
        picker.allowedContentTypes = [UTType(filenameExtension: "slipbackup") ?? .json]
        picker.nameFieldStringValue = "Slip Backup.slipbackup"
        guard picker.runModal() == .OK, let url = picker.url else { return }
        do {
            try LibraryTransfer.archive(notebook.library).write(to: url, options: .atomic)
            message("Backup exported")
        } catch { operationError = "Couldn’t export your backup. \(error.localizedDescription)" }
    }

    func importNotes() {
        let picker = NSOpenPanel()
        picker.title = "Import notes"
        picker.message = "Choose Markdown files or a Slip backup. Imported notes are added to your library."
        picker.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText, UTType(filenameExtension: "slipbackup") ?? .json]
        picker.allowsMultipleSelection = true
        guard picker.runModal() == .OK else { return }
        do {
            var merged = notebook.library
            for url in picker.urls {
                let data = try Data(contentsOf: url)
                let incoming: NoteLibrary
                if url.pathExtension.lowercased() == "slipbackup" {
                    incoming = try LibraryTransfer.decodeArchive(data)
                } else {
                    incoming = NoteLibrary(notes: [try LibraryTransfer.markdownNote(data: data, filename: url.lastPathComponent)])
                }
                merged = LibraryTransfer.merging(incoming, into: merged)
            }
            let count = merged.notes.count - notebook.library.notes.count
            try notebook.replaceLibrary(merged)
            query = ""
            changeFilter(.all)
            refreshBackups()
            message("Imported \(count) \(count == 1 ? "note" : "notes")")
        } catch { operationError = "Couldn’t import these notes. \(error.localizedDescription)" }
    }

    func exportAllMarkdown() {
        let picker = NSOpenPanel()
        picker.title = "Export all notes as Markdown"
        picker.message = "Choose where to save a new folder containing your active notes and folders."
        picker.prompt = "Export here"
        picker.canChooseFiles = false
        picker.canChooseDirectories = true
        picker.canCreateDirectories = true
        guard picker.runModal() == .OK, let parent = picker.url else { return }
        do {
            let root = try MarkdownExporter.export(notebook.library, to: parent)
            NSWorkspace.shared.activateFileViewerSelecting([root])
            message("Markdown exported")
        } catch { operationError = "Couldn’t export all notes. \(error.localizedDescription)" }
    }

}
