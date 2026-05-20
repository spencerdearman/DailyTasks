//
//  AgentSuggestionService.swift
//  TetherMac
//
//  Created by Spencer Dearman.
//

import Foundation
import SwiftData

// MARK: - AgentSuggestion

/// A contextual suggestion the agent surfaces inline on task list screens.
struct AgentSuggestion: Identifiable, Equatable {
    let id = UUID()
    let kind: Kind
    let message: String
    let actionLabel: String
    /// The prompt to send to the TaskAgent when the user accepts.
    let agentPrompt: String

    enum Kind: String, Equatable {
        case overdueTasks
        case unsortedInbox
        case emptyToday
        case heavyDay
        case schedulingGap
    }

    static func == (lhs: AgentSuggestion, rhs: AgentSuggestion) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - AgentSuggestionService

/// Analyzes the current task/calendar state and returns contextual suggestions.
/// Pure local logic — no LLM calls.
enum AgentSuggestionService {

    /// Generate suggestions relevant to a specific sidebar screen.
    static func suggestions(
        for screen: SidebarSelection,
        tasks: [TaskItem],
        calendarEvents: [CalendarEvent] = []
    ) -> [AgentSuggestion] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let active = tasks.filter { $0.status == .active }

        var results: [AgentSuggestion] = []

        switch screen {
        case .today:
            // Overdue tasks
            let overdue = active.filter {
                guard let d = $0.effectiveDate else { return false }
                return d < today
            }
            if !overdue.isEmpty {
                results.append(AgentSuggestion(
                    kind: .overdueTasks,
                    message: overdue.count == 1
                        ? "You have 1 overdue task. Want me to reschedule it?"
                        : "You have \(overdue.count) overdue tasks. Want me to reschedule them?",
                    actionLabel: "Reschedule",
                    agentPrompt: "Reschedule all my overdue tasks to today"
                ))
            }

            // Heavy day — many tasks scheduled for today
            let todayTasks = active.filter {
                guard let d = $0.effectiveDate else { return false }
                return cal.isDateInToday(d)
            }
            if todayTasks.count >= 5 {
                results.append(AgentSuggestion(
                    kind: .heavyDay,
                    message: "You have \(todayTasks.count) tasks today — that's a lot. Want me to help prioritize?",
                    actionLabel: "Prioritize",
                    agentPrompt: "I have too many tasks today. Help me prioritize and suggest which ones to defer."
                ))
            }

            // Empty today
            if todayTasks.isEmpty && overdue.isEmpty {
                let inbox = active.filter(\.isInInbox)
                let unscheduled = active.filter { !$0.isInInbox && $0.whenDate == nil }
                let available = inbox.count + unscheduled.count
                if available > 0 {
                    results.append(AgentSuggestion(
                        kind: .emptyToday,
                        message: "Nothing scheduled today. You have \(available) unscheduled task\(available == 1 ? "" : "s") — want me to plan your day?",
                        actionLabel: "Plan my day",
                        agentPrompt: "Plan my day"
                    ))
                }
            }

        case .inbox:
            let inbox = active.filter(\.isInInbox)
            if !inbox.isEmpty {
                results.append(AgentSuggestion(
                    kind: .unsortedInbox,
                    message: inbox.count == 1
                        ? "1 unsorted task in your inbox. Want me to categorize it?"
                        : "\(inbox.count) unsorted tasks in your inbox. Want me to categorize them into your areas?",
                    actionLabel: "Categorize",
                    agentPrompt: "Categorize all my inbox tasks into the appropriate areas and projects"
                ))
            }

        default:
            break
        }

        // Only return the most relevant suggestion
        return Array(results.prefix(1))
    }
}
