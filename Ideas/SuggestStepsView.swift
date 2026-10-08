import SwiftUI

struct SuggestStepsView: View {
    @Environment(\.dismiss) private var dismiss
    let idea: Idea

    private struct Suggestion: Identifiable {
        let id = UUID()
        var text: String
        var isSelected = false
    }

    @State private var suggestions: [Suggestion] = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var errorMessage: String?

    private var selectedCount: Int {
        suggestions.filter { $0.isSelected && !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }.count
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Asking \(AIService.selectedProvider.displayName)…")
                } else if let errorMessage, suggestions.isEmpty {
                    ContentUnavailableView {
                        Label("Couldn't get suggestions", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Try again") {
                            Task { await loadFirstBatch() }
                        }
                    }
                } else {
                    List {
                        Section {
                            ForEach($suggestions) { $suggestion in
                                HStack(alignment: .firstTextBaseline) {
                                    Button {
                                        suggestion.isSelected.toggle()
                                    } label: {
                                        Image(systemName: suggestion.isSelected ? "checkmark.circle.fill" : "circle")
                                            .font(.title3)
                                            .foregroundStyle(suggestion.isSelected ? Color.accentColor : .secondary)
                                    }
                                    .buttonStyle(.borderless)

                                    TextField("Step", text: $suggestion.text)
                                        .submitLabel(.done)
                                }
                            }
                        } footer: {
                            Text("Tick the steps you want. Tap any text to edit it before adding.")
                        }

                        Section {
                            Button {
                                Task { await loadMore() }
                            } label: {
                                HStack {
                                    Label("Suggest more", systemImage: "sparkles")
                                    if isLoadingMore {
                                        Spacer()
                                        ProgressView()
                                    }
                                }
                            }
                            .disabled(isLoadingMore)
                        } footer: {
                            if let errorMessage {
                                Text(errorMessage).foregroundStyle(.red)
                            } else {
                                Text("Keeps the ones you ticked and replaces the rest with new ideas.")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Suggested steps")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(selectedCount == 0 ? "Add" : "Add \(selectedCount)") {
                        addSelected()
                    }
                    .disabled(selectedCount == 0)
                }
            }
            .task { await loadFirstBatch() }
        }
    }

    // MARK: - Loading

    private func fetch(avoiding extra: [String]) async throws -> [String] {
        try await AIService.suggestSteps(
            title: idea.title,
            notes: idea.notes,
            existingSteps: idea.sortedSteps.map { $0.title } + extra
        )
    }

    private func loadFirstBatch() async {
        isLoading = true
        errorMessage = nil
        do {
            suggestions = try await fetch(avoiding: []).map { Suggestion(text: $0) }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func loadMore() async {
        isLoadingMore = true
        errorMessage = nil
        do {
            // Ask the AI to avoid everything already shown, so the new batch is genuinely new.
            let shown = suggestions.map { $0.text }
            let fresh = try await fetch(avoiding: shown).map { Suggestion(text: $0) }
            let kept = suggestions.filter { $0.isSelected }
            withAnimation {
                suggestions = kept + fresh
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingMore = false
    }

    // MARK: - Saving

    private func addSelected() {
        var order = (idea.steps.map { $0.order }.max() ?? -1) + 1
        for suggestion in suggestions where suggestion.isSelected {
            let text = suggestion.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            idea.steps.append(Step(title: text, order: order))
            order += 1
        }
        dismiss()
    }
}
