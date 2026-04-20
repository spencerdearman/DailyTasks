import SwiftUI

struct TaskDetailView: View {
    @Bindable var task: DailyTask
    @Environment(\.dismiss) private var dismiss
    @State private var showingPushOptions = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Top Action Buttons
                HStack(spacing: 8) {
                    Button(action: {
                        withAnimation {
                            task.isCompleted = true
                        }
                        dismiss()
                    }) {
                        Image(systemName: "checkmark")
                            .font(.title2.bold())
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        showingPushOptions = true
                    } label: {
                        Image(systemName: "arrow.turn.up.right")
                            .font(.title2.bold())
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 6)
                
                // Content Card
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Title", text: $task.title)
                        .font(.headline)
                        .foregroundColor(.black)
                        .padding(.vertical, 2)
                        
                    TextField("Notes...", text: $task.notes, axis: .vertical)
                        .font(.body)
                        .foregroundColor(Color(white: 0.3)) // Dark gray
                        .frame(minHeight: 120, alignment: .topLeading)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .cornerRadius(16)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Push Task To...", isPresented: $showingPushOptions, titleVisibility: .visible) {
            Button("Tomorrow") { pushTask(days: 1) }
            Button("In 3 Days") { pushTask(days: 3) }
            Button("Next Week") { pushTask(days: 7) }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    private func pushTask(days: Int) {
        let calendar = Calendar.current
        if let targetDate = calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: .now)) {
            task.hiddenUntil = targetDate
            task.isCompleted = false // Force reset when actively hiding
            dismiss()
        }
    }
}
