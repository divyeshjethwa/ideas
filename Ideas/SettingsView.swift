import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AIService.providerKey) private var selectedProvider = AIProvider.groq.rawValue
    @State private var refreshID = UUID()

    var body: some View {
        NavigationStack {
            Form {
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
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { refreshID = UUID() }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

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
