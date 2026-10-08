import SwiftUI

struct SuggestStepsView: View {
    @Environment(\.dismiss) private var dismiss
    let idea: Idea

    @State private var suggestions: [String] = []
    @State private var selected: Set<Int> = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Asking \(AIService.selectedProvider.displayName)…")
                } else if let errorMessage {
                    ContentUnavailableView {
                        Label("Couldn't get suggestions", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Try again") {
                            Task { await load() }
                        }
                    }
                } else {
                    List {
                        Section {
                            ForEach(suggestions.indices, id: \.self) { index in
                                Button {
                                    toggle(index)
                                } label: {
                                    HStack(alignment: .top) {
                                        Image(systemName: selected.contains(index) ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(selected.contains(index) ? Color.accentColor : .secondary)
                                        Text(suggestions[index])
                                            .foregroundStyle(.primary)
                                    }
                                }
                            }
                        } footer: {
                            Text("Tick the steps you want to keep.")
                        }
                    }
                }
            }
            .navigationTitle("Suggested steps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(selected.isEmpty ? "Add" : "Add \(selected.count)") {
                        addSelected()
                    }
                    .disabled(selected.isEmpty)
                }
            }
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            suggestions = try await AIService.suggestSteps(
                title: idea.title,
                notes: idea.notes,
                existingSteps: idea.sortedSteps.map { $0.title }
            )
            selected = []
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func toggle(_ index: Int) {
        if selected.contains(index) {
            selected.remove(index)
        } else {
            selected.insert(index)
        }
    }

    private func addSelected() {
        var order = (idea.steps.map { $0.order }.max() ?? -1) + 1
        for index in suggestions.indices where selected.contains(index) {
            idea.steps.append(Step(title: suggestions[index], order: order))
            order += 1
        }
        dismiss()
    }
}
