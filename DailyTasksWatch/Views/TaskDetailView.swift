//
//  TaskDetailView.swift
//  DailyTasks Watch App
//
//  Created by Spencer Dearman.
//

import SwiftUI
import SwiftData

struct TaskDetailView: View {
    @Bindable var task: DailyTask
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showingPushOptions = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text(task.title)
                    .font(.title3.bold())
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
                HStack(spacing: 8) {
                    Button(action: {
                        withAnimation {
                            task.isCompleted = true
                        }
                        saveChanges()
                        dismiss()
                    }) {
                        Image(systemName: "checkmark")
                            .font(.title3.bold())
                            .foregroundColor(.green)
                            .frame(width: 48, height: 48)
                            .glassEffect()
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        showingPushOptions = true
                    } label: {
                        Image(systemName: "arrow.turn.up.right")
                            .font(.title3.bold())
                            .foregroundColor(.blue)
                            .frame(width: 48, height: 48)
                            .glassEffect()
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        modelContext.delete(task)
                        saveChanges()
                        dismiss()
                    } label: {
                        Image(systemName: "trash")
                            .font(.title3.bold())
                            .foregroundColor(.red)
                            .frame(width: 48, height: 48)
                            .glassEffect()
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 6)
                VStack(alignment: .leading) {
                    TextField("Add notes...", text: $task.notes, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .foregroundColor(.primary)
                        .frame(minHeight: 80, alignment: .topLeading)
                }
                .padding()
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            saveChanges()
        }
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
            task.isCompleted = false
            saveChanges()
            dismiss()
        }
    }
    
    private func saveChanges() {
        guard modelContext.hasChanges else { return }
        
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save Daily Tasks changes: \(error)")
        }
    }
}
