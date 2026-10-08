import SwiftUI
import SwiftData

struct IdeaListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Idea.createdAt, order: .reverse) private var ideas: [Idea]
    @State private var showingAdd = false
    @State private var searchText = ""
    @State private var statusFilter: IdeaStatus? = nil
    @State private var showingSettings = false
    
    private var filteredIdeas: [Idea] {
        var result = ideas

        if let statusFilter {
            result = result.filter { $0.status == statusFilter }
        }

        let query = searchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(query) ||
                $0.notes.localizedCaseInsensitiveContains(query)
            }
        }

        return result.filter { $0.isPinned } + result.filter { !$0.isPinned }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredIdeas) { idea in
                    NavigationLink {
                        IdeaEditView(idea: idea)
                    } label: {
                        IdeaRow(idea: idea)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        if let next = idea.status.next {
                            Button {
                                idea.status = next
                            } label: {
                                Label(next.rawValue, systemImage: "arrow.right.circle")
                            }
                            .tint(next.color)
                        }
                        Button {
                            idea.isPinned.toggle()
                        } label: {
                            Label(idea.isPinned ? "Unpin" : "Pin",
                                  systemImage: idea.isPinned ? "pin.slash" : "pin")
                        }
                        .tint(.yellow)
                    }
                }
                .onDelete(perform: delete)
            }
            .overlay {
                if ideas.isEmpty {
                    ContentUnavailableView(
                        "No ideas yet",
                        systemImage: "lightbulb",
                        description: Text("Tap + to add your first one.")
                    )
                } else if filteredIdeas.isEmpty {
                    if searchText.isEmpty, let statusFilter {
                        ContentUnavailableView(
                            "Nothing in \(statusFilter.rawValue)",
                            systemImage: "line.3.horizontal.decrease.circle",
                            description: Text("Try a different status.")
                        )
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                }
            }
            .navigationTitle("Ideas")
            .searchable(text: $searchText, prompt: "Search ideas")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Status", selection: $statusFilter) {
                            Text("All").tag(IdeaStatus?.none)
                            ForEach(IdeaStatus.allCases) { status in
                                Text(status.rawValue).tag(Optional(status))
                            }
                        }
                    } label: {
                        Image(systemName: statusFilter == nil
                              ? "line.3.horizontal.decrease.circle"
                              : "line.3.horizontal.decrease.circle.fill")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                NavigationStack {
                    IdeaEditView(idea: nil)
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(filteredIdeas[index])
        }
    }
}

struct IdeaRow: View {
    let idea: Idea

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if idea.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
                Text(idea.title)
                    .font(.headline)
            }
            if let next = idea.nextStep {
                Text("Next: \(next.title)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if !idea.steps.isEmpty {
                ProgressView(value: idea.progress)
                    .tint(idea.status.color)
            }
            HStack {
                Text(idea.status.rawValue)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(idea.status.color.opacity(0.15))
                    .foregroundStyle(idea.status.color)
                    .clipShape(Capsule())
                Spacer()
                Text(idea.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

extension IdeaStatus {
    var color: Color {
        switch self {
        case .idea: .gray
        case .exploring: .orange
        case .building: .green
        case .shipped: .blue
        case .dropped: .red
        }
    }
}
