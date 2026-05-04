import Foundation
import SwiftData

@Model
final class Heading {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var sortOrder: Double = 0
    
    var project: Project?
    
    @Relationship(deleteRule: .nullify, inverse: \TaskItem.heading)
    var tasks: [TaskItem]?
    
    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        sortOrder: Double = 0,
        project: Project? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.sortOrder = sortOrder
        self.project = project
        self.tasks = []
    }
}
