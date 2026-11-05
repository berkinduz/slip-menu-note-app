import SwiftUI
import SlipCore

struct DataSettings: View {
    @Bindable var workspace: Workspace

    var body: some View {
        VStack(spacing: 20) {
            SettingsSection("iCloud Drive sync") {
                SettingsRow(workspace.sync.status, detail: "Choose the same iCloud Drive folder on both Macs.") {
                    Button(workspace.sync.folder == nil ? "Choose folder…" : "Change folder…") { workspace.sync.chooseFolder() }
                        .disabled(workspace.sync.isSyncing || !workspace.notebook.canWrite)
                }
                if let folder = workspace.sync.folder {
                    SettingsDivider()
                    SettingsRow(folder.lastPathComponent, detail: folder.path) {
                        Button("Sync now") { Task { await workspace.sync.synchronize() } }.disabled(workspace.sync.isSyncing)
                        Button("Turn off") { workspace.sync.disable() }.disabled(workspace.sync.isSyncing)
                    }
                    if let date = workspace.sync.lastCheckedAt {
                        Text("Folder last checked \(date.formatted(date: .abbreviated, time: .shortened)). iCloud Drive handles transfer to your other Mac.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let error = workspace.sync.errorMessage {
                    Text(error).font(.callout).foregroundStyle(.orange).textSelection(.enabled)
                }
                if let message = workspace.sync.conflictMessage {
                    Text(message).font(.callout).foregroundStyle(.secondary)
                }
            }
            SettingsSection("Take your notes with you") {
                SettingsRow("Import", detail: "Add Markdown files or a Slip backup without replacing existing notes.") {
                    Button("Import…") { workspace.importNotes() }.disabled(!workspace.notebook.canWrite)
                }
                SettingsDivider()
                SettingsRow("Markdown", detail: "Export all active notes, organized in folders.") {
                    Button("Export all…") { workspace.exportAllMarkdown() }.disabled(!workspace.notebook.canWrite)
                }
                SettingsDivider()
                SettingsRow("Slip backup", detail: "Include folders, tags, pinned notes and Trash.") {
                    Button("Export backup…") { workspace.exportBackup() }.disabled(!workspace.notebook.canWrite)
                }
            }
            SettingsSection("Local backups") {
                SettingsRow("Restore from a file", detail: "Recover an exported Slip backup, including on a new Mac.") {
                    Button("Choose backup…") { workspace.chooseBackupToRestore() }
                }
                SettingsDivider()
                SettingsRow("Automatic snapshots", detail: "A snapshot is kept before saved notes change, at most once every 30 minutes. The latest 30 are retained.") {
                    Button("Back up now") { workspace.createBackup() }.disabled(!workspace.notebook.canWrite)
                }
                if workspace.backups.isEmpty {
                    Text("Your first snapshot appears after you edit saved notes.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(workspace.backups, id: \.url) { backup in
                        SettingsDivider()
                        SettingsRow(backup.createdAt.formatted(date: .abbreviated, time: .standard)) {
                            Button("Restore…") { workspace.backupToRestore = backup.url }
                        }
                    }
                }
            }
        }
        .onAppear { workspace.refreshBackups() }
        .alert("Restore this backup?", isPresented: Binding(get: { workspace.backupToRestore != nil }, set: { if !$0 { workspace.backupToRestore = nil } })) {
            Button("Cancel", role: .cancel) { workspace.backupToRestore = nil }
            Button("Restore", role: .destructive) {
                if let url = workspace.backupToRestore { workspace.restoreBackup(url) }
                workspace.backupToRestore = nil
            }
        } message: {
            Text("This replaces your current notes and folders. A safety backup is created first. If sync is on, these changes will also sync.")
        }
        .alert("Couldn’t complete this action", isPresented: Binding(get: { workspace.operationError != nil }, set: { if !$0 { workspace.operationError = nil } })) {
            Button("OK", role: .cancel) { workspace.operationError = nil }
        } message: { Text(workspace.operationError ?? "") }
    }
}
