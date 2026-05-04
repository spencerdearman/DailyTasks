import Foundation
import SwiftData

@Model
final class Project {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var goalSummary: String = ""
    var tintHex: String = "#2E6BC6"
    var sortOrder: Double = 0
    
    var area: Area?
    
    @Relationship(deleteRule: .cascade, inverse: \Heading.project)
    var headings: [Heading]?
    
    @Relationship(deleteRule: .nullify, inverse: \TaskItem.project)
    var tasks: [TaskItem]?
    
    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        goalSummary: String = "",
        tintHex: String = "#2E6BC6",
        sortOrder: Double = 0,
        area: Area? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.goalSummary = goalSummary
        self.tintHex = tintHex
        self.sortOrder = sortOrder
        self.area = area
        self.headings = []
        self.tasks = []
    }
}
