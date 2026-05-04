import SwiftData
import SwiftUI

struct TaskCollectionView: View {
    let title: String
    let tasks: [TaskItem]
    var eveningTasks: [TaskItem] = []
    let events: [CalendarEvent]
    @Binding var expandedTaskID: UUID?
    @Binding var completingTaskIDs: Set<UUID>
    let onToggle: (TaskItem) -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HeaderCard(title: title)
                
                if !events.isEmpty {
                    EventStrip(events: events)
                }
                
                if tasks.isEmpty && eveningTasks.isEmpty {
                    EmptyState(title: title)
                } else {
                    TaskSection(
                        title: "Tasks",
                        tasks: tasks,
                        expandedTaskID: $expandedTaskID,
                        completingTaskIDs: $completingTaskIDs,
                        onToggle: onToggle
                    )
                    if !eveningTasks.isEmpty {
                        TaskSection(
                            title: "This Evening",
                            tasks: eveningTasks,
                            expandedTaskID: $expandedTaskID,
                            completingTaskIDs: $completingTaskIDs,
                            onToggle: onToggle
                        )
                    }
                }
            }
            .padding(28)
        }
    }
}
