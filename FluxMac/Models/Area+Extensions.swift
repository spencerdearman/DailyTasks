import Foundation
import SwiftData

extension Area {
    var projectList: [Project] {
        projects ?? []
    }
    
    var taskList: [TaskItem] {
        tasks ?? []
    }
    
    var activeTaskCount: Int {
        taskList.filter { !$0.isCompleted && $0.project == nil }.count
        + projectList.reduce(0) { $0 + $1.activeTaskCount }
    }
}
