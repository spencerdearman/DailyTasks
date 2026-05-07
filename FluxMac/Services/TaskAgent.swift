//
//  TaskAgent.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import Foundation
import SwiftData

// MARK: - Agent Response

struct AgentResponse {
    let message: String
    let affectedTaskIDs: [UUID]
    let subtasks: [String]?
    let taskCards: [TaskCard]?
    let eventCards: [EventCard]?

    init(message: String, affectedTaskIDs: [UUID] = [], subtasks: [String]? = nil, taskCards: [TaskCard]? = nil, eventCards: [EventCard]? = nil) {
        self.message = message
        self.affectedTaskIDs = affectedTaskIDs
        self.subtasks = subtasks
        self.taskCards = taskCards
        self.eventCards = eventCards
    }
}

struct TaskCard: Identifiable {
    let id: UUID
    let title: String
    let project: String?
    let area: String?
    let whenDate: Date?
    let deadline: Date?
    let isCompleted: Bool
}

struct EventCard: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let isAllDay: Bool
}

// MARK: - TaskAgent

@Observable
final class TaskAgent {
    var isProcessing = false
    var lastResponse: AgentResponse?

    private let gemini = GeminiService()
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    func process(_ input: String, apiKey: String, context: ModelContext, areas: [Area], projects: [Project], tasks: [TaskItem], calendarEvents: [CalendarEvent]) async -> AgentResponse {
        print("[TaskAgent] process called with input: \"\(input)\", apiKey empty: \(apiKey.isEmpty)")
        isProcessing = true
        defer {
            isProcessing = false
            print("[TaskAgent] isProcessing set to false")
        }

        // If no API key, use keyword fallback
        guard !apiKey.isEmpty else {
            print("[TaskAgent] No API key, using keyword fallback")
            let response = keywordFallback(input: input, context: context, areas: areas, projects: projects, tasks: tasks)
            lastResponse = response
            return response
        }

        // Build system prompt with full context
        let systemPrompt = buildSystemPrompt(areas: areas, projects: projects, tasks: tasks, calendarEvents: calendarEvents)
        print("[TaskAgent] System prompt built (\(systemPrompt.count) chars), calling Gemini...")

        do {
            let geminiResponse = try await gemini.send(input, apiKey: apiKey, systemPrompt: systemPrompt)
            print("[TaskAgent] Gemini returned action: \(geminiResponse.action), message: \(geminiResponse.message ?? "nil")")
            let response = await execute(geminiResponse, context: context, areas: areas, projects: projects, tasks: tasks, calendarEvents: calendarEvents)
            print("[TaskAgent] Executed action, final message: \(response.message.prefix(100))")
            lastResponse = response
            return response
        } catch {
            print("[TaskAgent] ERROR from Gemini: \(error)")
            // On API error, try keyword fallback
            let fallbackResponse = keywordFallback(input: input, context: context, areas: areas, projects: projects, tasks: tasks)
            lastResponse = fallbackResponse
            return fallbackResponse
        }
    }

    func clearConversation() async {
        await gemini.clearHistory()
    }

    // MARK: - Execute Gemini Response

    private func execute(_ response: GeminiActionResponse, context: ModelContext, areas: [Area], projects: [Project], tasks: [TaskItem], calendarEvents: [CalendarEvent]) async -> AgentResponse {
        let message = response.message ?? "Done"

        switch response.action {
        case "create_task":
            return doCreateTask(
                title: response.title ?? "Untitled",
                notes: response.notes ?? "",
                projectName: response.targetProject,
                areaName: response.targetArea,
                date: response.date,
                context: context, areas: areas, projects: projects,
                geminiMessage: message
            )

        case "complete_task":
            return doCompleteTask(
                searchText: response.searchText ?? response.title ?? "",
                tasks: tasks, context: context,
                geminiMessage: message
            )

        case "move_task":
            return doMoveTask(
                searchText: response.searchText ?? "",
                targetProject: response.targetProject,
                targetArea: response.targetArea,
                tasks: tasks, areas: areas, projects: projects, context: context,
                geminiMessage: message
            )

        case "schedule_task":
            return doScheduleTask(
                searchText: response.searchText ?? "",
                date: response.date ?? "today",
                tasks: tasks, context: context,
                geminiMessage: message
            )

        case "defer_task":
            return doDeferTask(
                searchText: response.searchText ?? "",
                tasks: tasks, context: context,
                geminiMessage: message
            )

        case "list_tasks":
            return doListTasks(
                filter: response.filter ?? "today",
                tasks: tasks, areas: areas, projects: projects,
                calendarEvents: calendarEvents,
                geminiMessage: message
            )

        case "decompose_task":
            return AgentResponse(
                message: message,
                subtasks: response.subtasks
            )

        case "plan_day", "reschedule_overdue", "query", "chat":
            // Check if the message references calendar events — attach event cards
            let eventCards = matchCalendarEvents(message: message, calendarEvents: calendarEvents)
            let taskCards = matchTaskCards(message: message, tasks: tasks)
            return AgentResponse(message: message, taskCards: taskCards.isEmpty ? nil : taskCards, eventCards: eventCards.isEmpty ? nil : eventCards)

        default:
            return AgentResponse(message: message)
        }
    }

    // MARK: - Action Implementations

    private func doCreateTask(title: String, notes: String, projectName: String?, areaName: String?, date: String?, context: ModelContext, areas: [Area], projects: [Project], geminiMessage: String) -> AgentResponse {
        let project = projectName.flatMap { findProject(named: $0, in: projects) }
        let area = areaName.flatMap { findArea(named: $0, in: areas) } ?? project?.area
        let whenDate = date.flatMap { parseDate($0) }

        let task = TaskItem(
            title: title,
            notes: notes,
            whenDate: whenDate,
            status: .active,
            isInInbox: area == nil && project == nil,
            area: area,
            project: project
        )
        context.insert(task)
        try? context.save()

        return AgentResponse(message: geminiMessage, affectedTaskIDs: [task.id])
    }

    private func doCompleteTask(searchText: String, tasks: [TaskItem], context: ModelContext, geminiMessage: String) -> AgentResponse {
        let active = tasks.filter { $0.status == .active }
        guard let match = bestMatch(for: searchText, in: active) else {
            return AgentResponse(message: "Couldn't find a task matching \"\(searchText)\"")
        }
        match.markComplete()
        try? context.save()
        return AgentResponse(message: geminiMessage, affectedTaskIDs: [match.id])
    }

    private func doMoveTask(searchText: String, targetProject: String?, targetArea: String?, tasks: [TaskItem], areas: [Area], projects: [Project], context: ModelContext, geminiMessage: String) -> AgentResponse {
        let active = tasks.filter { !$0.isCompleted }
        guard let match = bestMatch(for: searchText, in: active) else {
            return AgentResponse(message: "Couldn't find a task matching \"\(searchText)\"")
        }

        let proj = targetProject.flatMap { findProject(named: $0, in: projects) }
        let area = targetArea.flatMap { findArea(named: $0, in: areas) } ?? proj?.area

        match.project = proj
        match.area = area
        match.heading = nil
        match.isInInbox = area == nil && proj == nil
        match.updatedAt = .now
        try? context.save()

        return AgentResponse(message: geminiMessage, affectedTaskIDs: [match.id])
    }

    private func doScheduleTask(searchText: String, date: String, tasks: [TaskItem], context: ModelContext, geminiMessage: String) -> AgentResponse {
        let active = tasks.filter { $0.status == .active }
        guard let match = bestMatch(for: searchText, in: active) else {
            return AgentResponse(message: "Couldn't find a task matching \"\(searchText)\"")
        }
        guard let whenDate = parseDate(date) else {
            return AgentResponse(message: "Couldn't understand the date \"\(date)\"")
        }
        match.whenDate = whenDate
        match.updatedAt = .now
        try? context.save()
        return AgentResponse(message: geminiMessage, affectedTaskIDs: [match.id])
    }

    private func doDeferTask(searchText: String, tasks: [TaskItem], context: ModelContext, geminiMessage: String) -> AgentResponse {
        let active = tasks.filter { $0.status == .active }
        guard let match = bestMatch(for: searchText, in: active) else {
            return AgentResponse(message: "Couldn't find a task matching \"\(searchText)\"")
        }
        match.status = .someday
        match.whenDate = nil
        match.updatedAt = .now
        try? context.save()
        return AgentResponse(message: geminiMessage, affectedTaskIDs: [match.id])
    }

    private func doListTasks(filter: String, tasks: [TaskItem], areas: [Area], projects: [Project], calendarEvents: [CalendarEvent] = [], geminiMessage: String) -> AgentResponse {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let active = tasks.filter { $0.status == .active }

        let filtered: [TaskItem]

        switch filter.lowercased() {
        case "inbox":
            filtered = active.filter(\.isInInbox)
        case "today":
            filtered = active.filter {
                guard let d = $0.effectiveDate else { return false }
                return calendar.isDate(d, inSameDayAs: today)
            }
        case "tomorrow":
            guard let tmrw = calendar.date(byAdding: .day, value: 1, to: today) else {
                return AgentResponse(message: geminiMessage)
            }
            filtered = active.filter {
                guard let d = $0.effectiveDate else { return false }
                return calendar.isDate(d, inSameDayAs: tmrw)
            }
        case "upcoming":
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? .now
            filtered = active.filter {
                guard let d = $0.effectiveDate else { return false }
                return d >= tomorrow
            }
        case "open":
            filtered = active.filter { !$0.isInInbox && $0.whenDate == nil }
        case "later":
            filtered = tasks.filter { $0.status == .someday }
        case "done":
            filtered = Array(tasks.filter(\.isCompleted)
                .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
                .prefix(10))
        default:
            // Try project match
            if let project = findProject(named: filter, in: projects) {
                filtered = project.taskList.filter { !$0.isCompleted }
            } else if let area = findArea(named: filter, in: areas) {
                let areaTasks = tasks.filter { $0.area?.id == area.id || $0.project?.area?.id == area.id }
                filtered = areaTasks.filter { !$0.isCompleted }
            } else {
                filtered = active.filter { $0.title.localizedCaseInsensitiveContains(filter) }
            }
        }

        // Build event cards for calendar-related filters
        let eventCards: [EventCard]?
        let filterLower = filter.lowercased()
        if filterLower == "today" || filterLower == "tomorrow" || filterLower == "upcoming" {
            let calendar = Calendar.current
            let matchingEvents: [CalendarEvent]
            if filterLower == "today" {
                matchingEvents = calendarEvents.filter { calendar.isDateInToday($0.startDate) }
            } else if filterLower == "tomorrow" {
                matchingEvents = calendarEvents.filter { calendar.isDateInTomorrow($0.startDate) }
            } else {
                matchingEvents = calendarEvents
            }
            eventCards = matchingEvents.isEmpty ? nil : matchingEvents.map { event in
                EventCard(id: event.id, title: event.title, startDate: event.startDate, endDate: event.endDate, location: event.location, isAllDay: event.isAllDay)
            }
        } else {
            eventCards = nil
        }

        if filtered.isEmpty && eventCards == nil {
            print("[TaskAgent] doListTasks: no local tasks matched filter '\(filter)'")
            return AgentResponse(message: geminiMessage)
        }

        let cards: [TaskCard]? = filtered.isEmpty ? nil : Array(filtered.prefix(15).map { task in
            TaskCard(
                id: task.id,
                title: task.title,
                project: task.project?.title,
                area: task.area?.title,
                whenDate: task.whenDate,
                deadline: task.deadline,
                isCompleted: task.isCompleted
            )
        })
        print("[TaskAgent] doListTasks: returning \(cards?.count ?? 0) task cards, \(eventCards?.count ?? 0) event cards")
        return AgentResponse(message: geminiMessage, affectedTaskIDs: filtered.map(\.id), taskCards: cards, eventCards: eventCards)
    }

    // MARK: - Keyword Fallback (no API key)

    private func keywordFallback(input: String, context: ModelContext, areas: [Area], projects: [Project], tasks: [TaskItem]) -> AgentResponse {
        let lowered = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let active = tasks.filter { $0.status == .active }

        // Simple list queries
        if lowered.contains("inbox") {
            let inbox = active.filter(\.isInInbox)
            return listResponse("Inbox", tasks: inbox)
        }
        if lowered.contains("today") {
            let today = Calendar.current.startOfDay(for: .now)
            let todayTasks = active.filter { guard let d = $0.whenDate else { return false }; return Calendar.current.isDate(d, inSameDayAs: today) }
            return listResponse("Today", tasks: todayTasks)
        }
        if lowered.contains("tomorrow") {
            let tmrw = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now))!
            let tmrwTasks = active.filter { guard let d = $0.whenDate else { return false }; return Calendar.current.isDate(d, inSameDayAs: tmrw) }
            return listResponse("Tomorrow", tasks: tmrwTasks)
        }
        if lowered.contains("done") || lowered.contains("completed") {
            let done = Array(tasks.filter(\.isCompleted).sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }.prefix(10))
            return listResponse("Done (recent)", tasks: done)
        }

        // Check project/area references
        for project in projects {
            if lowered.contains(project.title.lowercased()) {
                let projTasks = project.taskList.filter { !$0.isCompleted }
                return listResponse(project.title, tasks: projTasks)
            }
        }
        for area in areas {
            if lowered.contains(area.title.lowercased()) {
                let areaTasks = tasks.filter { ($0.area?.id == area.id || $0.project?.area?.id == area.id) && !$0.isCompleted }
                return listResponse(area.title, tasks: areaTasks)
            }
        }

        // Create task
        if lowered.hasPrefix("add ") || lowered.hasPrefix("create ") {
            let prefixLen = lowered.hasPrefix("add ") ? 4 : 7
            let title = String(input.dropFirst(prefixLen)).trimmingCharacters(in: .whitespaces)
            if !title.isEmpty {
                let task = TaskItem(title: title, status: .active, isInInbox: true)
                context.insert(task)
                try? context.save()
                return AgentResponse(message: "Created \"\(title)\" in Inbox", affectedTaskIDs: [task.id])
            }
        }

        return AgentResponse(message: "Set up your Gemini API key in Settings to unlock the full agent. For now, try: \"show today\", \"add <task>\", or ask about a project by name.")
    }

    private func listResponse(_ label: String, tasks: [TaskItem]) -> AgentResponse {
        if tasks.isEmpty {
            return AgentResponse(message: "No tasks in \(label)")
        }
        let lines = tasks.prefix(15).map { "  · \($0.title)" }.joined(separator: "\n")
        return AgentResponse(message: "\(label) — \(tasks.count) task(s):\n\(lines)", affectedTaskIDs: tasks.map(\.id))
    }

    // MARK: - Card Matching for Query/Chat Responses

    private func matchCalendarEvents(message: String, calendarEvents: [CalendarEvent]) -> [EventCard] {
        // Match calendar events mentioned in the message by title
        let messageLower = message.lowercased()
        return calendarEvents.filter { event in
            messageLower.contains(event.title.lowercased())
        }.map { event in
            EventCard(id: event.id, title: event.title, startDate: event.startDate, endDate: event.endDate, location: event.location, isAllDay: event.isAllDay)
        }
    }

    private func matchTaskCards(message: String, tasks: [TaskItem]) -> [TaskCard] {
        let messageLower = message.lowercased()
        return tasks.filter { task in
            messageLower.contains(task.title.lowercased())
        }.prefix(10).map { task in
            TaskCard(id: task.id, title: task.title, project: task.project?.title, area: task.area?.title, whenDate: task.whenDate, deadline: task.deadline, isCompleted: task.isCompleted)
        }
    }

    // MARK: - Helpers

    private func bestMatch(for searchText: String, in tasks: [TaskItem]) -> TaskItem? {
        let lowered = searchText.lowercased()
        if let exact = tasks.first(where: { $0.title.lowercased() == lowered }) { return exact }
        if let hit = tasks.first(where: { $0.title.localizedCaseInsensitiveContains(lowered) }) { return hit }
        let searchWords = Set(lowered.split(separator: " ").map(String.init).filter { $0.count > 2 })
        guard !searchWords.isEmpty else { return nil }
        let scored = tasks.compactMap { task -> (TaskItem, Int)? in
            let titleWords = Set(task.title.lowercased().split(separator: " ").map(String.init))
            let overlap = titleWords.intersection(searchWords).count
            return overlap > 0 ? (task, overlap) : nil
        }
        return scored.max(by: { $0.1 < $1.1 })?.0
    }

    private func findArea(named name: String, in areas: [Area]) -> Area? {
        guard !name.isEmpty else { return nil }
        if let exact = areas.first(where: { $0.title.lowercased() == name.lowercased() }) { return exact }
        return areas.first { $0.title.localizedCaseInsensitiveContains(name) }
    }

    private func findProject(named name: String, in projects: [Project]) -> Project? {
        guard !name.isEmpty else { return nil }
        if let exact = projects.first(where: { $0.title.lowercased() == name.lowercased() }) { return exact }
        return projects.first { $0.title.localizedCaseInsensitiveContains(name) }
    }

    private func parseDate(_ string: String) -> Date? {
        let lowered = string.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        switch lowered {
        case "today", "now": return today
        case "tomorrow": return calendar.date(byAdding: .day, value: 1, to: today)
        case "next week": return calendar.date(byAdding: .weekOfYear, value: 1, to: today)
        default:
            let weekdays = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
            if let idx = weekdays.firstIndex(of: lowered) {
                let targetDay = idx + 1
                let currentDay = calendar.component(.weekday, from: today)
                let daysAhead = (targetDay - currentDay + 7) % 7
                let offset = daysAhead == 0 ? 7 : daysAhead
                return calendar.date(byAdding: .day, value: offset, to: today)
            }
            return dateFormatter.date(from: lowered)
        }
    }

    // MARK: - System Prompt

    private func buildSystemPrompt(areas: [Area], projects: [Project], tasks: [TaskItem], calendarEvents: [CalendarEvent]) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd (EEEE)"
        let todayStr = fmt.string(from: Date())

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"

        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "h:mm a"

        let completedTasks = tasks.filter { $0.isCompleted }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        let somedayTasksList = tasks.filter { $0.status == .someday }

        return GeminiPromptBuilder.buildSystemPrompt(
            areas: areas.map { (name: $0.title, symbol: $0.symbolName) },
            projects: projects.map { (name: $0.title, areaName: $0.area?.title) },
            activeTasks: tasks.filter { $0.status == .active }.map { task in
                (
                    title: task.title,
                    project: task.project?.title,
                    area: task.area?.title,
                    whenDate: task.whenDate.map { dateFmt.string(from: $0) },
                    deadline: task.deadline.map { dateFmt.string(from: $0) },
                    isInInbox: task.isInInbox
                )
            },
            completedTasks: completedTasks.map { task in
                (
                    title: task.title,
                    completedAt: task.completedAt.map { dateFmt.string(from: $0) }
                )
            },
            somedayTasks: somedayTasksList.map { task in
                (
                    title: task.title,
                    project: task.project?.title,
                    area: task.area?.title
                )
            },
            calendarEvents: calendarEvents.map { event in
                (
                    title: event.title,
                    date: dateFmt.string(from: event.startDate),
                    start: timeFmt.string(from: event.startDate),
                    end: timeFmt.string(from: event.endDate),
                    location: event.location
                )
            },
            todayDate: todayStr
        )
    }
}
