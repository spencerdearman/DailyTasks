//
//  TaskMeta.swift
//  FluxApp
//
//  Created by Spencer Dearman.
//

import SwiftUI

// MARK: - TaskMeta

/// A flow-layout row of metadata badges for a task (project, dates, tags, checklist progress).
struct TaskMeta: View {

    // MARK: - Properties

    let task: TaskItem

    // MARK: - Body

    var body: some View {
        FlowLayout(spacing: 6) {
            if let project = task.project {
                Badge(text: project.title, tint: project.tintHex)
            } else if let area = task.area {
                Badge(text: area.title, tint: area.tintHex)
            }

            if let date = task.whenDate {
                DateBadge(date: date, isDeadline: false)
            }

            if let deadline = task.deadline {
                HStack(spacing: 4) {
                    Image(systemName: "flag.fill")
                    .font(.system(size: 9))
                    Text(deadlineLabel(deadline))
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.12), in: Capsule())
            }

            if task.hasCalendarEvent {
                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 9))
                    Text(task.suggestedCalendarStartAt.formatted(.dateTime.month(.abbreviated).day().hour(.defaultDigits(amPM: .abbreviated)).minute()))
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.12), in: Capsule())
            }

            ForEach(task.tagList.prefix(3)) { tag in
                Badge(text: tag.title, tint: tag.tintHex)
            }

            if !task.checklistItems.isEmpty {
                HStack(spacing: 3) {
                    Image(systemName: "checklist")
                        .font(.system(size: 9))
                    Text("\(task.checklistItems.filter(\.isCompleted).count)/\(task.checklistItems.count)")
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.06), in: Capsule())
            }
        }
    }

    // MARK: - Helpers

    private func deadlineLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        if hour == 0 && minute == 0 {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
        return date.formatted(.dateTime.month(.abbreviated).day().hour(.defaultDigits(amPM: .abbreviated)).minute())
    }
}
