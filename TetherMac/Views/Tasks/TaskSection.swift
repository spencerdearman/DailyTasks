//
//  TaskSection.swift
//  TetherMac
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

// MARK: - TaskSection

/// A titled group of task rows with reordering and deletion support.
struct TaskSection: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.agentActivity) private var agentActivity
    let title: String
    let tasks: [TaskItem]
    @Binding var expandedTaskID: UUID?
    @Binding var completingTaskIDs: Set<UUID>
    let onToggle: (TaskItem) -> Void
    /// Task IDs recently affected by the agent — shown with a highlight animation.
    var agentHighlightIDs: Set<UUID> = []

    @Query(sort: \Area.sortOrder) private var allAreas: [Area]
    @Query(sort: \Project.sortOrder) private var allProjects: [Project]

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
                    let isHighlighted = agentHighlightIDs.contains(task.id)

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
                            Button {
                                onToggle(task)
                            } label: {
                                Label(task.isCompleted ? "Mark Incomplete" : "Mark Complete",
                                      systemImage: task.isCompleted ? "circle" : "checkmark.circle")
                            }

                            Divider()

                            // Move to area/project
                            Menu {
                                Button {
                                    task.area = nil
                                    task.project = nil
                                    task.heading = nil
                                    task.isInInbox = true
                                    task.updatedAt = .now
                                    try? modelContext.save()
                                } label: {
                                    Label("Inbox", systemImage: "tray")
                                }

                                Divider()

                                ForEach(allAreas) { area in
                                    Button {
                                        task.area = area
                                        task.project = nil
                                        task.heading = nil
                                        task.isInInbox = false
                                        task.updatedAt = .now
                                        try? modelContext.save()
                                    } label: {
                                        Label(area.title, systemImage: area.symbolName)
                                    }

                                    ForEach(allProjects.filter { $0.area?.id == area.id }) { project in
                                        Button {
                                            task.area = area
                                            task.project = project
                                            task.heading = nil
                                            task.isInInbox = false
                                            task.updatedAt = .now
                                            try? modelContext.save()
                                        } label: {
                                            Label("  \(project.title)", systemImage: "paperplane")
                                        }
                                    }
                                }
                            } label: {
                                Label("Move to…", systemImage: "arrow.turn.right.up")
                            }

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
                    .modifier(AgentGlowModifier(
                        isHighlighted: isHighlighted || agentActivity.touchedIDs.contains(task.id),
                        isFirst: index == 0,
                        isLast: index == tasks.count - 1
                    ))
                }
            }
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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


// MARK: - AgentGlowModifier

/// Applies an inline highlight when a task is affected by the agent.
/// Uses plain Rectangle fills — the parent container's `.clipShape` handles corner rounding.
struct AgentGlowModifier: ViewModifier {
    let isHighlighted: Bool
    var isFirst: Bool = false
    var isLast: Bool = false

    @State private var glowOpacity: Double = 0
    @State private var shimmerOffset: CGFloat = -0.5

    func body(content: Content) -> some View {
        content
            // Background tint — extends into parent's 6pt padding for first/last rows
            .background {
                Rectangle()
                    .fill(Color(red: 0.38, green: 0.30, blue: 0.80).opacity(0.07 * glowOpacity))
                    .padding(.top, isFirst ? -6 : 0)
                    .padding(.bottom, isLast ? -6 : 0)
                    .allowsHitTesting(false)
            }
            // Left accent bar
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.48, green: 0.52, blue: 0.95).opacity(0.7),  // periwinkle
                                Color(red: 0.30, green: 0.22, blue: 0.65).opacity(0.6), // violet
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3)
                    .padding(.vertical, 5)
                    .padding(.leading, 8)
                    .opacity(glowOpacity)
                    .allowsHitTesting(false)
            }
            // Shimmer sweep — plain rect, clipped by parent
            .overlay {
                GeometryReader { geo in
                    let width = geo.size.width
                    LinearGradient(
                        colors: [
                            .clear,
                            Color(red: 0.45, green: 0.45, blue: 0.90).opacity(0.04),
                            Color(red: 0.45, green: 0.45, blue: 0.90).opacity(0.08),
                            Color(red: 0.45, green: 0.45, blue: 0.90).opacity(0.04),
                            .clear,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: width * 0.4)
                    .offset(x: shimmerOffset * width)
                    .allowsHitTesting(false)
                }
                .padding(.top, isFirst ? -6 : 0)
                .padding(.bottom, isLast ? -6 : 0)
                .clipped()
                .opacity(glowOpacity > 0 ? 1 : 0)
            }
            .onChange(of: isHighlighted) { _, highlighted in
                if highlighted {
                    playAnimation()
                } else {
                    withAnimation(.easeOut(duration: 0.4)) {
                        glowOpacity = 0
                    }
                }
            }
            .onAppear {
                if isHighlighted { playAnimation() }
            }
    }

    private func playAnimation() {
        shimmerOffset = -0.5
        glowOpacity = 0
        withAnimation(.easeOut(duration: 0.4)) {
            glowOpacity = 1.0
        }
        withAnimation(.easeInOut(duration: 0.8).delay(0.15)) {
            shimmerOffset = 1.5
        }
        withAnimation(.easeInOut(duration: 1.2).delay(2.0)) {
            glowOpacity = 0
        }
    }
}

// MARK: - TaskActionMode

/// The currently active inline action panel in an expanded task row.
enum TaskActionMode: Hashable {
    case calendar
    case tags
    case subtasks
    case deadline
}
