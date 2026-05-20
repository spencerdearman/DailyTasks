//
//  AgentActivityService.swift
//  TetherApp
//
//  Created by Spencer Dearman.
//

import Foundation
import SwiftUI

// MARK: - AgentActivityService

/// Shared observable that broadcasts which tasks the agent is currently affecting.
/// Used by TaskCard to show glow/shimmer animations on agent-touched tasks.
@Observable
final class AgentActivityService {

    /// Task IDs that were recently created or modified by the agent.
    var touchedIDs: Set<UUID> = []

    /// Whether the agent is currently processing a request.
    var isWorking: Bool = false

    /// The latest compact message from the agent (shown as inline confirmation).
    var lastMessage: String?

    /// Tracks pending removal tasks so they can be cancelled if re-touched.
    private var removalTasks: [UUID: Task<Void, Never>] = [:]

    /// Mark task IDs as touched by the agent. Auto-clears after `duration`.
    func markTouched(_ ids: [UUID], duration: TimeInterval = 3.0) {
        for id in ids {
            // Cancel any pending removal for this ID
            removalTasks[id]?.cancel()
            touchedIDs.insert(id)

            // Schedule removal
            removalTasks[id] = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(duration))
                guard !Task.isCancelled else { return }
                _ = withAnimation(.easeOut(duration: 0.6)) {
                    self?.touchedIDs.remove(id)
                }
                self?.removalTasks.removeValue(forKey: id)
            }
        }
    }

    /// Clear all state.
    func clear() {
        removalTasks.values.forEach { $0.cancel() }
        removalTasks.removeAll()
        touchedIDs.removeAll()
        isWorking = false
        lastMessage = nil
    }
}

// MARK: - Environment Key

extension EnvironmentValues {
    @Entry var agentActivity: AgentActivityService = AgentActivityService()
}
