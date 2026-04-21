import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \DailyTask.createdAt) private var tasks: [DailyTask]
    @Environment(\.modelContext) private var modelContext
    
    // Core filter mapping exactly reflecting watchOS logic
    var visibleTasks: [DailyTask] {
        tasks.filter { task in
            if let hiddenDate = task.hiddenUntil {
                return hiddenDate <= Date()
            }
            return true
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Elegant Menu Bar Header
            HStack {
                Text("Daily Tasks")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Track current progress dynamically
                Text("\(visibleTasks.filter(\.isCompleted).count) / \(max(visibleTasks.count, 1))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(8)
            }
            .padding()
            .background(Material.bar)
            
            Divider()
            
            // Read-Only Task Stream
            ScrollView {
                VStack(spacing: 12) {
                    if visibleTasks.isEmpty {
                        Text("No active tasks.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(.top, 40)
                    } else {
                        ForEach(visibleTasks) { task in
                            HStack {
                                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(task.isCompleted ? Color.accentColor : .gray)
                                    .font(.title3)
                                
                                Text(task.title)
                                    .font(.body)
                                    .strikethrough(task.isCompleted)
                                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                                
                                Spacer()
                                
                                if task.streak > 0 {
                                    HStack(spacing: 2) {
                                        Image(systemName: "flame.fill")
                                            .font(.caption2)
                                        Text("\(task.streak)")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                    }
                                    .foregroundStyle(Color.accentColor)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.15))
                                    .cornerRadius(6)
                                }
                            }
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(12)
            }
        }
        .frame(minWidth: 320, minHeight: 450)
    }
}
