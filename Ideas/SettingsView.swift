import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var ideas: [Idea]

    @AppStorage(AIService.providerKey) private var selectedProvider = AIProvider.groq.rawValue
    @State private var refreshID = UUID()

    @State private var exportDocument: IdeasBackupDocument?
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var backupMessage: String?

    private var backupFilename: String {
        "Ideas Backup " + Date.now.formatted(.iso8601.year().month().day())
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: AI
                Section {
                    Picker("Use", selection: $selectedProvider) {
                        ForEach(AIProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider.rawValue)
                        }
                    }
                } header: {
                    Text("AI for suggestions")
                } footer: {
                    Text("Free tiers may use what you send to improve their models. Avoid sending anything secret.")
                }

                Section("Connections") {
                    ForEach(AIProvider.allCases) { provider in
                        NavigationLink {
                            ProviderDetailView(provider: provider)
                        } label: {
                            ProviderRow(provider: provider)
                        }
                    }
                }
                .id(refreshID)

                // MARK: Backup
                Section {
                    Button {
                        exportBackup()
                    } label: {
                        Label("Export backup", systemImage: "square.and.arrow.up")
                    }
                    .disabled(ideas.isEmpty)

                    Button {
                        showingImporter = true
                    } label: {
                        Label("Import backup", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Backup")
                } footer: {
                    Text(backupMessage ?? "Saves all your ideas and steps as a file in Files or iCloud Drive. Importing adds ideas back and skips ones you already have.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { refreshID = UUID() }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: backupFilename
            ) { result in
                switch result {
                case .success:
                    backupMessage = "Backup saved ✅ (\(ideas.count) ideas)"
                case .failure(let error):
                    backupMessage = "Export failed: \(error.localizedDescription)"
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.json]
            ) { result in
                switch result {
                case .success(let url):
                    do {
                        let outcome = try BackupService.restore(from: url, into: context, existing: ideas)
                        var text = "Imported \(outcome.added) ideas"
                        if outcome.skipped > 0 {
                            text += ", skipped \(outcome.skipped) you already had"
                        }
                        backupMessage = text + " ✅"
                    } catch {
                        backupMessage = "Couldn't read that file. Make sure it's an Ideas backup."
                    }
                case .failure(let error):
                    backupMessage = "Import failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func exportBackup() {
        do {
            exportDocument = IdeasBackupDocument(data: try BackupService.export(ideas))
            showingExporter = true
        } catch {
            backupMessage = "Export failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Provider list row

private struct ProviderRow: View {
    let provider: AIProvider

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.displayName)
                Text(provider.isFree ? "Free" : "Paid")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if KeychainStore.read(provider.rawValue) != nil {
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
    }
}

// MARK: - Provider detail (Get key / Paste key / Model)

private struct ProviderDetailView: View {
    let provider: AIProvider

    @Environment(\.openURL) private var openURL
    @State private var isConnected = false
    @State private var model = ""
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                Button {
                    openURL(provider.keyPageURL)
                } label: {
                    Label("Get key", systemImage: "safari")
                }

                Button {
                    pasteKey()
                } label: {
                    Label("Paste key", systemImage: "doc.on.clipboard")
                }

                if isConnected {
                    Button(role: .destructive) {
                        KeychainStore.delete(provider.rawValue)
                        isConnected = false
                        message = nil
                    } label: {
                        Label("Disconnect", systemImage: "xmark.circle")
                    }
                }
            } header: {
                Text(isConnected ? "Connected ✅" : "Not connected")
            } footer: {
                Text(message ?? "Tap Get key, sign in, create a key and copy it. Then come back here and tap Paste key.")
            }

            Section {
                TextField(provider.defaultModel, text: $model)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: model) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: AIService.modelKey(provider))
                    }
            } header: {
                Text("Model")
            } footer: {
                Text("Leave empty to use the default. Only change this if the default stops working.")
            }
        }
        .navigationTitle(provider.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneButton()
        .onAppear {
            isConnected = KeychainStore.read(provider.rawValue) != nil
            model = UserDefaults.standard.string(forKey: AIService.modelKey(provider)) ?? ""
        }
    }

    private func pasteKey() {
        let text = (UIPasteboard.general.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 20, !text.contains(" ") else {
            message = "That doesn't look like a key. Copy it again and retry."
            return
        }
        KeychainStore.save(text, for: provider.rawValue)
        UIPasteboard.general.string = ""   // clear it so the key doesn't linger on the clipboard
        isConnected = true
        message = "Key saved securely on this iPhone."
    }
}
