//
//  TaskRowView.swift
//  FluxWatch
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

struct TaskRowView: View {

    @Bindable var task: TaskItem
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HStack {
            Button {
                if task.isCompleted {
                    task.reopen()
                } else {
                    task.markComplete()
                }
                try? modelContext.save()
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? Color.accentColor : .gray)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                if let project = task.project {
                    Text(project.title)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if task.deadline != nil {
                Image(systemName: "flag.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
            }
        }
    }
}
