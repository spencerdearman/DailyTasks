import SwiftData
import SwiftUI

struct TaskSection: View {
    @Environment(\.modelContext) private var modelContext
    let title: String
    let tasks: [TaskItem]
    @Binding var expandedTaskID: UUID?
    @Binding var completingTaskIDs: Set<UUID>
    let onToggle: (TaskItem) -> Void
    
    private enum MoveDirection { case up, down }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(tasks.count)")
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 0) {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                    VStack(spacing: 0) {
                        TaskRow(
                            task: task,
                            isExpanded: expandedTaskID == task.id,
                            isCompleting: completingTaskIDs.contains(task.id),
                            onToggle: { onToggle(task) },
                            onTap: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                    expandedTaskID = expandedTaskID == task.id ? nil : task.id
                                }
                            },
                            onDelete: {
                                withAnimation(.easeOut(duration: 0.25)) {
                                    if expandedTaskID == task.id { expandedTaskID = nil }
                                    completingTaskIDs.remove(task.id)
                                    modelContext.delete(task)
                                    try? modelContext.save()
                                }
                            }
                        )
                        .contextMenu {
                            if index > 0 {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        moveTask(at: index, direction: .up)
                                    }
                                } label: {
                                    Label("Move Up", systemImage: "arrow.up")
                                }
                            }
                            if index < tasks.count - 1 {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        moveTask(at: index, direction: .down)
                                    }
                                } label: {
                                    Label("Move Down", systemImage: "arrow.down")
                                }
                            }
                            Divider()
                            Button(role: .destructive) {
                                withAnimation(.easeOut(duration: 0.25)) {
                                    if expandedTaskID == task.id { expandedTaskID = nil }
                                    completingTaskIDs.remove(task.id)
                                    modelContext.delete(task)
                                    try? modelContext.save()
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        
                        if task.id != tasks.last?.id {
                            Divider()
                                .padding(.leading, 46)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
    }
    
    private func moveTask(at index: Int, direction: MoveDirection) {
        let targetIndex = direction == .up ? index - 1 : index + 1
        guard targetIndex >= 0 && targetIndex < tasks.count else { return }
        
        // Ensure unique sort orders
        for (i, t) in tasks.enumerated() {
            t.sortOrder = Double(i)
        }
        
        let a = tasks[index]
        let b = tasks[targetIndex]
        let temp = a.sortOrder
        a.sortOrder = b.sortOrder
        b.sortOrder = temp
        a.updatedAt = .now
        b.updatedAt = .now
        try? modelContext.save()
    }
}


// MARK: - Task Row

enum TaskActionMode: Hashable {
    case calendar
    case tags
    case subtasks
    case deadline
}
