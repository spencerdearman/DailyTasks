//
//  InlineTaskAdder.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

// MARK: - InlineTaskAdder

/// A compact inline text field for quickly adding tasks within a project section.
struct InlineTaskAdder: View {
    @Environment(\.modelContext) private var modelContext
    let project: Project
    let area: Area?
    let heading: Heading?
    
    @State private var title = ""
    @State private var isActive = false
    
    var body: some View {
        if isActive {
            HStack(spacing: 10) {
                Image(systemName: "circle")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                
                TextField("New task…", text: $title)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .onSubmit { addTask() }
                    .onExitCommand {
                        isActive = false
                        title = ""
                    }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
        } else {
            Button {
                isActive = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                    Text("Add Task")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.leading, 18)
        }
    }
    
    private func addTask() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let task = TaskItem(
            title: trimmed,
            isInInbox: false,
            sortOrder: Double(project.taskList.count),
            area: area,
            project: project,
            heading: heading
        )
        modelContext.insert(task)
        try? modelContext.save()
        title = ""
    }
}
