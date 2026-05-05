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
        let calendar = Calendar.current
        if let calendarStartAt {
            return calendarStartAt
        }
        
        if let deadline {
            let components = calendar.dateComponents([.hour, .minute], from: deadline)
            if components.hour != 0 || components.minute != 0 {
                return deadline
            }
            return calendar.date(bySettingHour: isEvening ? 18 : 9, minute: 0, second: 0, of: deadline) ?? deadline
        }
        
        if let whenDate {
            return calendar.date(bySettingHour: isEvening ? 18 : 9, minute: 0, second: 0, of: whenDate) ?? whenDate
        }
        
        let now = Date()
        let nextHour = calendar.dateInterval(of: .hour, for: now)?.end ?? now.addingTimeInterval(3600)
        return nextHour
    }
    
    var hasExplicitDeadlineTime: Bool {
        guard let deadline else { return false }
        let components = Calendar.current.dateComponents([.hour, .minute], from: deadline)
        return components.hour != 0 || components.minute != 0
    }
    
    var hasExplicitCalendarStartTime: Bool {
        guard let calendarStartAt else { return false }
        let components = Calendar.current.dateComponents([.hour, .minute], from: calendarStartAt)
        return components.hour != 0 || components.minute != 0
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
