import SwiftData
import SwiftUI

struct TaskListScreen: View {
    let title: String
    let tasks: [TaskItem]
    let defaultSelection: SidebarSelection?

    @State private var showingQuickEntry = false
    @State private var editingTask: TaskItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HeaderCard(title: title)

                if tasks.isEmpty {
                    EmptyCard(title: title)
                } else {
                    LazyVStack(spacing: 14) {
                        ForEach(tasks) { task in
                            TaskCard(task: task) {
                                editingTask = task
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .pullToQuickFind()
        .background(AppBackground())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingQuickEntry = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingQuickEntry) {
            QuickEntrySheet(defaultSelection: defaultSelection)
        }
        .sheet(item: $editingTask) { task in
            TaskEditorSheet(task: task)
        }
    }
}
