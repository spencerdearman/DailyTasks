//
//  TaskCollectionView.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

// MARK: - TaskCollectionView

/// A scrollable list of tasks grouped into sections, with optional event display.
struct TaskCollectionView: View {
    let title: String
    let tasks: [TaskItem]
    var eveningTasks: [TaskItem] = []
    let events: [CalendarEvent]
    @Binding var expandedTaskID: UUID?
    @Binding var completingTaskIDs: Set<UUID>
    let onToggle: (TaskItem) -> Void
    var synthesis: DailySynthesis? = nil
    var onOpenSynthesis: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(title)
                    .font(.system(size: 34, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Morning briefing banner
                if let synthesis {
                    SynthesisBanner(synthesis: synthesis, onTap: { onOpenSynthesis?() })
                }

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

// MARK: - Synthesis Banner

/// A compact card shown at the top of the Today view when a morning briefing is available.
struct SynthesisBanner: View {
    let synthesis: DailySynthesis
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 36, height: 36)

                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.blue)
                }

                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    Text("Morning Briefing")
                        .font(.system(size: 13, weight: .semibold))

                    Text(briefingSummary)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Badges
                HStack(spacing: 6) {
                    if synthesis.overdueCount > 0 {
                        overdueBadge
                    }
                    if !synthesis.conflicts.isEmpty {
                        conflictBadge
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var briefingSummary: String {
        if !synthesis.greeting.isEmpty {
            // Take the first sentence of the greeting
            let firstSentence = synthesis.greeting.components(separatedBy: ".").first ?? synthesis.greeting
            return String(firstSentence.prefix(80))
        }
        return "Your daily plan is ready"
    }

    private var overdueBadge: some View {
        Text("\(synthesis.overdueCount) overdue")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.red)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.red.opacity(0.1), in: Capsule())
    }

    private var conflictBadge: some View {
        Text("\(synthesis.conflicts.count) conflict\(synthesis.conflicts.count == 1 ? "" : "s")")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.orange)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.orange.opacity(0.1), in: Capsule())
    }
}
