import Foundation
import SwiftData

enum IdeaStatus: String, CaseIterable, Identifiable {
    case idea = "Just an idea"
    case exploring = "Exploring"
    case building = "Building"
    case shipped = "Shipped"
    case dropped = "Dropped"

    var id: String { rawValue }

    var next: IdeaStatus? {
        switch self {
        case .idea: .exploring
        case .exploring: .building
        case .building: .shipped
        case .shipped, .dropped: nil
        }
    }
}

@Model
final class Idea {
    var title: String
    var notes: String
    var statusRaw: String
    var createdAt: Date
    var isPinned: Bool = false
    @Relationship(deleteRule: .cascade, inverse: \Step.idea)
    var steps: [Step] = []

    var status: IdeaStatus {
        get { IdeaStatus(rawValue: statusRaw) ?? .idea }
        set { statusRaw = newValue.rawValue }
    }
    var sortedSteps: [Step] { steps.sorted { $0.order < $1.order } }
    var doneCount: Int { steps.filter { $0.isDone }.count }
    var progress: Double {
        steps.isEmpty ? 0 : Double(doneCount) / Double(steps.count)
    }
    var nextStep: Step? { sortedSteps.first { !$0.isDone } }

    init(title: String, notes: String = "", status: IdeaStatus = .idea) {
        self.title = title
        self.notes = notes
        self.statusRaw = status.rawValue
        self.createdAt = .now
    }
}
