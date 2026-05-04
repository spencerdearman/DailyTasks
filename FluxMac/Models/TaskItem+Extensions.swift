import Foundation
import SwiftData

extension TaskItem {
    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }
    
    var isCompleted: Bool {
        status == .completed
    }
    
    var effectiveDate: Date? {
        whenDate ?? deadline
    }
    
    var hasCalendarEvent: Bool {
        calendarEventID?.isEmpty == false
    }
    
    var suggestedCalendarStartAt: Date {
        if let calendarStartAt {
            return calendarStartAt
        }
        
        let calendar = Calendar.current
        if let deadline {
            return deadline
        }
        
        if let whenDate {
            return calendar.date(bySettingHour: isEvening ? 18 : 9, minute: 0, second: 0, of: whenDate) ?? whenDate
        }
        
        let now = Date()
        let nextHour = calendar.dateInterval(of: .hour, for: now)?.end ?? now.addingTimeInterval(3600)
        return nextHour
    }
    
    var tagList: [Tag] {
        tagAssignments?.compactMap(\.tag) ?? []
    }
    
    var tagAssignmentList: [TaskTagAssignment] {
        tagAssignments ?? []
    }
    
    var checklistItems: [ChecklistItem] {
        checklist ?? []
    }
    
    var plainContext: String {
        [
            title,
            notes,
            area?.title,
            project?.title,
            tagList.map(\.title).joined(separator: " ")
        ]
            .compactMap { $0 }
            .joined(separator: " ")
    }
    
    var recurrenceDescription: String? {
        guard let rule = recurrenceRule else { return nil }
        switch rule {
        case "daily": return "Every day"
        case "weekly": return "Every week"
        case "biweekly": return "Every 2 weeks"
        case "monthly": return "Every month"
        case "yearly": return "Every year"
        default: return rule
        }
    }
    
    func markComplete() {
        status = .completed
        completedAt = Date()
        updatedAt = Date()
    }
    
    func reopen() {
        status = .active
        completedAt = nil
        updatedAt = Date()
    }
}
