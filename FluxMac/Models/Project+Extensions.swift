import Foundation
import SwiftData

extension Project {
    var headingList: [Heading] {
        headings ?? []
    }
    
    var taskList: [TaskItem] {
        tasks ?? []
    }
    
    var sortedHeadings: [Heading] {
        headingList.sorted {
            if $0.sortOrder == $1.sortOrder {
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            return $0.sortOrder < $1.sortOrder
        }
    }
    
    var sortedTasks: [TaskItem] {
        taskList.sorted {
            if $0.sortOrder == $1.sortOrder {
                return $0.createdAt < $1.createdAt
            }
            return $0.sortOrder < $1.sortOrder
        }
    }
    
    var activeTaskCount: Int {
        taskList.filter { !$0.isCompleted }.count
    }
    
    var completionRatio: Double {
        guard !taskList.isEmpty else { return 0 }
        return Double(taskList.filter(\.isCompleted).count) / Double(taskList.count)
    }
}
