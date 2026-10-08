import SwiftUI
import SwiftData

struct IdeaEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let idea: Idea?

    @State private var title: String
    @State private var notes: String
    @State private var status: IdeaStatus
    @State private var newStepTitle = ""
    @State private var suggestedStatus: IdeaStatus?
    @State private var showingSuggestions = false
    @State private var stepsEditMode: EditMode = .inactive
    @State private var editingStepID: PersistentIdentifier?

    init(idea: Idea?) {
        self.idea = idea
        _title = State(initialValue: idea?.title ?? "")
        _notes = State(initialValue: idea?.notes ?? "")
        _status = State(initialValue: idea?.status ?? .idea)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Form {
            Section("Idea") {
                TextField("Title", text: $title)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...10)
            }

            Section("Status") {
                Picker("Status", selection: $status) {
                    ForEach(IdeaStatus.allCases) { status in
                        Text(status.rawValue).tag(status)
                    }
                }
                .pickerStyle(.menu)
            }

            if let idea {
                Section {
                    if !idea.steps.isEmpty {
                        ProgressView(value: idea.progress) {
                            Text("\(idea.doneCount) of \(idea.steps.count) steps done")
                                .font(.subheadline)
                        }
                        .tint(status.color)
                    }

                    ForEach(idea.sortedSteps) { step in
                        StepRow(
                            step: step,
                            isEditing: editingStepID == step.persistentModelID,
                            onToggle: { toggle(step) },
                            onFinishEditing: { finishEditing(step) }
                        )
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteStep(step)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                editingStepID = step.persistentModelID
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        .contextMenu {
                            Button {
                                editingStepID = step.persistentModelID
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                deleteStep(step)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onMove { source, destination in
                        var reordered = idea.sortedSteps
                        reordered.move(fromOffsets: source, toOffset: destination)
                        for (index, step) in reordered.enumerated() {
                            step.order = index
                        }
                    }

                    Button {
                        showingSuggestions = true
                    } label: {
                        Label("Suggest steps with AI", systemImage: "sparkles")
                    }

                    HStack {
                        TextField("Add a step", text: $newStepTitle)
                            .submitLabel(.done)
                            .onSubmit(addStep)
                        Button(action: addStep) {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(newStepTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    HStack {
                        Text("Steps")
                        Spacer()
                        if idea.steps.count > 1 {
                            Button(stepsEditMode.isEditing ? "Done" : "Reorder") {
                                withAnimation {
                                    stepsEditMode = stepsEditMode.isEditing ? .inactive : .active
                                }
                            }
                            .textCase(nil)
                        }
                    }
                } footer: {
                    if let next = idea.nextStep {
                        Text("Next: \(next.title)")
                    } else if !idea.steps.isEmpty {
                        Text("All steps done 🎉")
                    }
                }
            }
        }
        .navigationTitle(idea == nil ? "New Idea" : "Edit Idea")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, $stepsEditMode)
        .keyboardDoneButton()
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $showingSuggestions) {
            if let idea {
                SuggestStepsView(idea: idea)
            }
        }
        .alert(
            "Move to \(suggestedStatus?.rawValue ?? "")?",
            isPresented: Binding(
                get: { suggestedStatus != nil },
                set: { if !$0 { suggestedStatus = nil } }
            )
        ) {
            Button("Move") {
                if let newStatus = suggestedStatus {
                    status = newStatus
                    idea?.status = newStatus
                }
            }
            Button("Not now", role: .cancel) { }
        }
        .toolbar {
            if idea == nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(trimmedTitle.isEmpty)
            }
        }
    }

    // MARK: - Steps

    private func deleteStep(_ step: Step) {
        guard let idea else { return }
        idea.steps.removeAll { $0.persistentModelID == step.persistentModelID }
        context.delete(step)
    }

    private func finishEditing(_ step: Step) {
        guard editingStepID == step.persistentModelID else { return }
        editingStepID = nil
        step.title = step.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if step.title.isEmpty {
            deleteStep(step)
        }
    }

    private func addStep() {
        guard let idea else { return }
        let text = newStepTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let nextOrder = (idea.steps.map { $0.order }.max() ?? -1) + 1
        idea.steps.append(Step(title: text, order: nextOrder))
        newStepTitle = ""
    }

    private func toggle(_ step: Step) {
        step.isDone.toggle()
        guard let idea, step.isDone else { return }

        if idea.doneCount == idea.steps.count, status != .shipped {
            suggestedStatus = .shipped
        } else if idea.doneCount == 1, status == .idea || status == .exploring {
            suggestedStatus = .building
        }
    }

    // MARK: - Save

    private func save() {
        if let idea {
            idea.title = trimmedTitle
            idea.notes = notes
            idea.status = status
        } else {
            context.insert(Idea(title: trimmedTitle, notes: notes, status: status))
        }
        dismiss()
    }
}

// MARK: - Step row

private struct StepRow: View {
    @Bindable var step: Step
    let isEditing: Bool
    let onToggle: () -> Void
    let onFinishEditing: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            if isEditing {
                Image(systemName: "pencil")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                TextField("Step", text: $step.title)
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit(onFinishEditing)
                    .task {
                        try? await Task.sleep(for: .milliseconds(150))
                        isFocused = true
                    }
            } else {
                Button(action: onToggle) {
                    Image(systemName: step.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(step.isDone ? .green : .secondary)
                }
                .buttonStyle(.borderless)
                Text(step.title)
                    .strikethrough(step.isDone)
                    .foregroundStyle(step.isDone ? .secondary : .primary)
                Spacer(minLength: 0)
            }
        }
        .listRowBackground(isEditing ? Color.accentColor.opacity(0.12) : nil)
        .onChange(of: isFocused) { _, focused in
            if !focused && isEditing {
                onFinishEditing()
            }
        }
    }
}
