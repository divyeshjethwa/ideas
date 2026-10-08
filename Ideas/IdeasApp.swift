import SwiftUI
import SwiftData

@main
struct IdeasApp: App {
    var body: some Scene {
        WindowGroup {
            IdeaListView()
        }
        .modelContainer(for: [Idea.self, Step.self])
    }
}
