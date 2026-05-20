//
//  TaskCard.swift
//  TetherApp
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

// MARK: - TaskCard

/// A card displaying a single task with a completion toggle, metadata badges, and notes preview.
struct TaskCard: View {

    // MARK: - Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.agentActivity) private var agentActivity

    // MARK: - Properties

    @Bindable var task: TaskItem
    let onOpen: () -> Void

    // MARK: - State

    @State private var isCompleting = false
    @State private var glowOpacity: Double = 0
    @State private var shimmerOffset: CGFloat = -0.5

    // MARK: - Computed Properties

    private var isDone: Bool { isCompleting || task.isCompleted }
    private var isAgentHighlighted: Bool { agentActivity.touchedIDs.contains(task.id) }

    // MARK: - Body

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Button {
                toggleTask()
            } label: {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isDone ? .green : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)

            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(task.title)
                        .font(.body.weight(.medium))
                        .strikethrough(isDone)
                        .foregroundStyle(isDone ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !task.tagList.isEmpty || task.area != nil || task.project != nil || task.effectiveDate != nil || !task.checklistItems.isEmpty {
                        TaskMeta(task: task)
                    }

                    if !task.notes.isEmpty {
                        Text(task.notes)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(isCompleting ? 0.5 : 1.0)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            // Agent glow border
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.6),
                            Color.purple.opacity(0.4),
                            Color.blue.opacity(0.6),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .opacity(glowOpacity)
                .shadow(color: .blue.opacity(glowOpacity * 0.4), radius: 8, y: 2)
        }
        .overlay {
            // Shimmer sweep
            GeometryReader { geo in
                let width = geo.size.width
                LinearGradient(
                    colors: [
                        .clear,
                        Color.white.opacity(0.15),
                        Color.white.opacity(0.25),
                        Color.white.opacity(0.15),
                        .clear,
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: width * 0.4)
                .offset(x: shimmerOffset * width)
                .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(glowOpacity > 0 ? 1 : 0)
        }
        .onChange(of: isAgentHighlighted) { _, highlighted in
            if highlighted {
                playHighlightAnimation()
            } else {
                withAnimation(.easeOut(duration: 0.4)) {
                    glowOpacity = 0
                }
            }
        }
        .onAppear {
            if isAgentHighlighted {
                playHighlightAnimation()
            }
        }
        .contextMenu {
            Button(task.isCompleted ? "Mark Incomplete" : "Mark Complete") {
                toggleTask()
            }
        }
    }

    // MARK: - Highlight Animation

    private func playHighlightAnimation() {
        // Reset
        shimmerOffset = -0.5
        glowOpacity = 0

        // Glow in
        withAnimation(.easeOut(duration: 0.4)) {
            glowOpacity = 0.8
        }

        // Shimmer sweep
        withAnimation(.easeInOut(duration: 1.0).delay(0.1)) {
            shimmerOffset = 1.5
        }

        // Glow out
        withAnimation(.easeInOut(duration: 1.5).delay(1.5)) {
            glowOpacity = 0
        }
    }

    // MARK: - Actions

    /// Toggles the task between complete and incomplete with a delayed commit.
    private func toggleTask() {
        if isCompleting {
            // User tapped again while completing -- undo
            withAnimation(.easeInOut(duration: 0.25)) {
                isCompleting = false
            }
            return
        }

        if task.isCompleted {
            task.reopen()
            try? modelContext.save()
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                isCompleting = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                guard isCompleting else { return }
                withAnimation(.easeInOut(duration: 0.5)) {
                    isCompleting = false
                    task.markComplete()
                    try? modelContext.save()
                }
            }
        }
    }
}
