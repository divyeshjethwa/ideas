import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - What goes in the backup file

nonisolated struct BackupFile: Codable {
    var version = 1
    var exportedAt = Date()
    var ideas: [IdeaBackup]
}

nonisolated struct IdeaBackup: Codable {
    var title: String
    var notes: String
    var status: String
    var createdAt: Date
    var isPinned: Bool
    var steps: [StepBackup]
}

nonisolated struct StepBackup: Codable {
    var title: String
    var isDone: Bool
    var order: Int
}

// MARK: - The file itself (used by the Save to Files sheet)

nonisolated struct IdeasBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Export and import

enum BackupService {
    static func export(_ ideas: [Idea]) throws -> Data {
        let file = BackupFile(ideas: ideas.map { idea in
            IdeaBackup(
                title: idea.title,
                notes: idea.notes,
                status: idea.statusRaw,
                createdAt: idea.createdAt,
                isPinned: idea.isPinned,
                steps: idea.sortedSteps.map {
                    StepBackup(title: $0.title, isDone: $0.isDone, order: $0.order)
                }
            )
        })

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(file)
    }

    /// Adds ideas from a backup file. Skips ideas you already have
    /// (same title and same creation time), so importing twice is safe.
    static func restore(from url: URL, into context: ModelContext, existing: [Idea]) throws -> (added: Int, skipped: Int) {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess { url.stopAccessingSecurityScopedResource() }
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file = try decoder.decode(BackupFile.self, from: data)

        var added = 0
        var skipped = 0

        for item in file.ideas {
            let alreadyHave = existing.contains {
                $0.title == item.title && abs($0.createdAt.timeIntervalSince(item.createdAt)) < 1
            }
            if alreadyHave {
                skipped += 1
                continue
            }

            let idea = Idea(
                title: item.title,
                notes: item.notes,
                status: IdeaStatus(rawValue: item.status) ?? .idea
            )
            idea.createdAt = item.createdAt
            idea.isPinned = item.isPinned
            context.insert(idea)

            for saved in item.steps {
                let step = Step(title: saved.title, order: saved.order)
                step.isDone = saved.isDone
                idea.steps.append(step)
            }
            added += 1
        }

        return (added, skipped)
    }
}
