import Foundation
import SwiftData

@Model
final class Step {
    var title: String
    var isDone: Bool = false
    var order: Int = 0
    var idea: Idea?

    init(title: String, order: Int) {
        self.title = title
        self.order = order
    }
}
