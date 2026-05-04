import Foundation
import SwiftData

@Model
final class TaskTagAssignment {
    var id: UUID = UUID()
    var task: TaskItem?
    var tag: Tag?
    
    init(
        id: UUID = UUID(),
        task: TaskItem? = nil,
        tag: Tag? = nil
    ) {
        self.id = id
        self.task = task
        self.tag = tag
    }
}
