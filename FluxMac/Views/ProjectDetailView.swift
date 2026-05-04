import SwiftData
import SwiftUI

struct ProjectDetailView: View {
    @Environment(\.modelContext) private var modelContext
    
    let project: Project
    @Binding var expandedTaskID: UUID?
    @Binding var completingTaskIDs: Set<UUID>
    @State private var newHeadingTitle = ""
    @State private var showAddHeading = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(project.title)
                    .font(.system(size: 32, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                
                // Simple notes editor
                TextField("Notes…", text: Binding(
                    get: { project.notes },
                    set: {
                        project.notes = $0
                        try? modelContext.save()
                    }
                ), axis: .vertical)
                .font(.body)
                .foregroundStyle(.secondary)
                .textFieldStyle(.plain)
                .lineLimit(2...10)
                .padding(16)
                .frame(minHeight: 56, alignment: .topLeading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                
                ForEach(project.sortedHeadings) { heading in
                    let headingTasks = project.sortedTasks.filter { $0.heading?.id == heading.id }
                    VStack(alignment: .leading, spacing: 8) {
                        if headingTasks.isEmpty {
                            // Just show heading title when no tasks
                            HStack {
                                Text(heading.title)
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("0")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            TaskSection(
                                title: heading.title,
                                tasks: headingTasks,
                                expandedTaskID: $expandedTaskID,
                                completingTaskIDs: $completingTaskIDs
                            ) { task in
                                if task.isCompleted { task.reopen() } else { task.markComplete() }
                                try? modelContext.save()
                            }
                        }
                        
                        InlineTaskAdder(
                            project: project,
                            area: project.area,
                            heading: heading
                        )
                    }
                }
                
                let ungroupedTasks = project.sortedTasks.filter { $0.heading == nil }
                VStack(alignment: .leading, spacing: 8) {
                    if !ungroupedTasks.isEmpty {
                        TaskSection(
                            title: "Tasks",
                            tasks: ungroupedTasks,
                            expandedTaskID: $expandedTaskID,
                            completingTaskIDs: $completingTaskIDs
                        ) { task in
                            if task.isCompleted { task.reopen() } else { task.markComplete() }
                            try? modelContext.save()
                        }
                    }
                    
                    InlineTaskAdder(
                        project: project,
                        area: project.area,
                        heading: nil
                    )
                }
                
                // Add heading
                if showAddHeading {
                    HStack(spacing: 10) {
                        TextField("Heading name…", text: $newHeadingTitle)
                            .textFieldStyle(.plain)
                            .font(.title3.weight(.semibold))
                            .onSubmit { addHeading() }
                        
                        Button("Add") { addHeading() }
                            .buttonStyle(.bordered)
                            .disabled(newHeadingTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        
                        Button { showAddHeading = false; newHeadingTitle = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 8)
                } else {
                    Button {
                        showAddHeading = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                            Text("Add Heading")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
            }
            .padding(28)
        }
        .background(Color.clear)
    }
    
    private func addHeading() {
        let title = newHeadingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let heading = Heading(
            title: title,
            sortOrder: Double(project.headingList.count),
            project: project
        )
        modelContext.insert(heading)
        try? modelContext.save()
        newHeadingTitle = ""
        showAddHeading = false
    }
}
