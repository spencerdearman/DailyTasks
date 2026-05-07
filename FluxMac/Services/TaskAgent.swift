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
    let isPlanDay: Bool

    init(message: String, affectedTaskIDs: [UUID] = [], subtasks: [String]? = nil, taskCards: [TaskCard]? = nil, eventCards: [EventCard]? = nil, isPlanDay: Bool = false) {
        self.message = message
        self.affectedTaskIDs = affectedTaskIDs
        self.subtasks = subtasks
        self.taskCards = taskCards
        self.eventCards = eventCards
        self.isPlanDay = isPlanDay
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

// MARK: - Execution Context

/// Bundles all dependencies the agent needs to execute actions.
/// Add new system capabilities here — all action methods receive this automatically.
struct AgentContext {
    let modelContext: ModelContext
    let calendarStore: CalendarStore?
    let locationService: LocationService?
    let areas: [Area]
    let projects: [Project]
    let tasks: [TaskItem]
    let calendarEvents: [CalendarEvent]
}

// MARK: - TaskAgent

@Observable
final class TaskAgent {
    var isProcessing = false
    var lastResponse: AgentResponse?

    private let gemini = GeminiService()
    private let categorizer = CategorizationService()
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Convenience overload that constructs an `AgentContext` from individual parameters.
    func process(
        _ input: String,
        apiKey: String,
        context modelContext: ModelContext,
        areas: [Area],
        projects: [Project],
        tasks: [TaskItem],
        calendarEvents: [CalendarEvent],
        calendarStore: CalendarStore?
    ) async -> AgentResponse {
        let ctx = AgentContext(
            modelContext: modelContext,
            calendarStore: calendarStore,
            locationService: nil,
            areas: areas,
            projects: projects,
            tasks: tasks,
            calendarEvents: calendarEvents
        )
        return await process(input, apiKey: apiKey, context: ctx)
    }

    func process(_ input: String, apiKey: String, context: AgentContext) async -> AgentResponse {
        print("[TaskAgent] process called with input: \"\(input)\", apiKey empty: \(apiKey.isEmpty)")
        isProcessing = true
        defer {
            isProcessing = false
            print("[TaskAgent] isProcessing set to false")
        }

        guard !apiKey.isEmpty else {
            print("[TaskAgent] No API key, using keyword fallback")
            let response = keywordFallback(input: input, ctx: context)
            lastResponse = response
            return response
        }

        let systemPrompt = buildSystemPrompt(ctx: context)
        print("[TaskAgent] System prompt built (\(systemPrompt.count) chars), calling Gemini...")

        do {
            let geminiResponse = try await gemini.send(input, apiKey: apiKey, systemPrompt: systemPrompt)
            print("[TaskAgent] Gemini returned action: \(geminiResponse.action), message: \(geminiResponse.message ?? "nil")")
            let response = await execute(geminiResponse, ctx: context)
            print("[TaskAgent] Executed action, final message: \(response.message.prefix(100))")
            lastResponse = response
            return response
        } catch {
            print("[TaskAgent] ERROR from Gemini: \(error)")
            let fallbackResponse = keywordFallback(input: input, ctx: context)
            lastResponse = fallbackResponse
            return fallbackResponse
        }
    }

    func clearConversation() async {
        await gemini.clearHistory()
    }

    // MARK: - Execute Gemini Response

    private func execute(_ response: GeminiActionResponse, ctx: AgentContext) async -> AgentResponse {
        let message = response.message ?? "Done"

        switch response.action {
        case "create_task":
            return await doCreateTask(response, message: message, ctx: ctx)

        case "complete_task":
            return doCompleteTask(
                searchText: response.searchText ?? response.title ?? "",
                message: message, ctx: ctx
            )

        case "move_task":
            return doMoveTask(
                searchText: response.searchText ?? "",
                targetProject: response.targetProject,
                targetArea: response.targetArea,
                message: message, ctx: ctx
            )

        case "schedule_task":
            return doScheduleTask(
                searchText: response.searchText ?? "",
                date: response.date ?? "today",
                message: message, ctx: ctx
            )

        case "defer_task":
            return doDeferTask(
                searchText: response.searchText ?? "",
                message: message, ctx: ctx
            )

        case "list_tasks":
            return doListTasks(
                filter: response.filter ?? "today",
                message: message, ctx: ctx
            )

        case "create_event":
            return await doCreateEvent(
                title: response.eventTitle ?? response.title ?? "New Event",
                startString: response.eventStart ?? response.date,
                endString: response.eventEnd,
                location: response.eventLocation,
                message: message, ctx: ctx
            )

        case "decompose_task":
            return AgentResponse(message: message, subtasks: response.subtasks)

        case "plan_day":
            // Always show today's tasks and events for daily planning
            return buildPlanDayResponse(message: message, ctx: ctx)

        case "reschedule_overdue":
            // Show overdue tasks
            let cal = Calendar.current
            let today = cal.startOfDay(for: .now)
            let overdue = ctx.tasks.filter {
                $0.status == .active && ($0.effectiveDate ?? .distantFuture) < today
            }
            let cards = overdue.prefix(15).map { task in
                TaskCard(id: task.id, title: task.title, project: task.project?.title, area: task.area?.title, whenDate: task.whenDate, deadline: task.deadline, isCompleted: false)
            }
            return AgentResponse(message: message, taskCards: cards.isEmpty ? nil : cards)

        case "query", "chat":
            let eventCards = matchCalendarEvents(message: message, calendarEvents: ctx.calendarEvents)
            let taskCards = matchTaskCards(message: message, tasks: ctx.tasks)
            return AgentResponse(
                message: message,
                taskCards: taskCards.isEmpty ? nil : taskCards,
                eventCards: eventCards.isEmpty ? nil : eventCards
            )

        default:
            return AgentResponse(message: message)
        }
    }

    // MARK: - Action: Create Task

    private func doCreateTask(_ response: GeminiActionResponse, message: String, ctx: AgentContext) async -> AgentResponse {
        let title = response.title ?? "Untitled"
        var project = response.targetProject.flatMap { findProject(named: $0, in: ctx.projects) }
        var area = response.targetArea.flatMap { findArea(named: $0, in: ctx.areas) } ?? project?.area
        let whenDate = response.date.flatMap { parseDate($0) }

        // Auto-categorize if Gemini didn't assign area/project
        if area == nil && project == nil {
            let classification = await categorizer.categorize(
                title: title,
                notes: response.notes ?? "",
                areas: ctx.areas.map { (name: $0.title, description: $0.notes) },
                projects: ctx.projects.map { (name: $0.title, areaName: $0.area?.title) },
                apiKey: UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
            )
            if let areaName = classification.area {
                area = findArea(named: areaName, in: ctx.areas)
            }
            if let projName = classification.project {
                project = findProject(named: projName, in: ctx.projects)
                if area == nil { area = project?.area }
            }
            if area != nil || project != nil {
                print("[TaskAgent] Auto-categorized '\(title)' → area: \(area?.title ?? "nil"), project: \(project?.title ?? "nil")")
            }
        }

        let task = TaskItem(
            title: title,
            notes: response.notes ?? "",
            whenDate: whenDate,
            status: .active,
            isInInbox: area == nil && project == nil,
            locationName: response.locationName,
            area: area,
            project: project
        )
        ctx.modelContext.insert(task)
        try? ctx.modelContext.save()

        let taskCard = TaskCard(id: task.id, title: task.title, project: project?.title, area: area?.title, whenDate: whenDate, deadline: nil, isCompleted: false)
        var eventCards: [EventCard]? = nil

        // If Gemini says to also add to calendar, create the event
        if response.addToCalendar == true, let calendarStore = ctx.calendarStore {
            let startDate = parseDatetime(response.eventStart ?? "") ?? whenDate ?? Date()
            let endDate: Date
            if let endStr = response.eventEnd, let parsed = parseDatetime(endStr) {
                endDate = parsed
            } else {
                endDate = startDate.addingTimeInterval(3600)
            }

            do {
                let event = try await calendarStore.createEvent(
                    title: title,
                    startDate: startDate,
                    endDate: endDate,
                    location: response.eventLocation
                )
                eventCards = [EventCard(id: event.id, title: event.title, startDate: event.startDate, endDate: event.endDate, location: event.location, isAllDay: false)]
                print("[TaskAgent] Also created calendar event for task: \(title)")
            } catch {
                print("[TaskAgent] Failed to create calendar event alongside task: \(error)")
            }
        }

        return AgentResponse(message: message, affectedTaskIDs: [task.id], taskCards: [taskCard], eventCards: eventCards)
    }

    // MARK: - Action: Complete Task

    private func doCompleteTask(searchText: String, message: String, ctx: AgentContext) -> AgentResponse {
        let active = ctx.tasks.filter { $0.status == .active }
        guard let match = bestMatch(for: searchText, in: active) else {
            return AgentResponse(message: "Couldn't find a task matching \"\(searchText)\"")
        }
        match.markComplete()
        try? ctx.modelContext.save()
        let card = TaskCard(id: match.id, title: match.title, project: match.project?.title, area: match.area?.title, whenDate: match.whenDate, deadline: match.deadline, isCompleted: true)
        return AgentResponse(message: message, affectedTaskIDs: [match.id], taskCards: [card])
    }

    // MARK: - Action: Move Task

    private func doMoveTask(searchText: String, targetProject: String?, targetArea: String?, message: String, ctx: AgentContext) -> AgentResponse {
        let active = ctx.tasks.filter { !$0.isCompleted }
        guard let match = bestMatch(for: searchText, in: active) else {
            return AgentResponse(message: "Couldn't find a task matching \"\(searchText)\"")
        }

        let proj = targetProject.flatMap { findProject(named: $0, in: ctx.projects) }
        let area = targetArea.flatMap { findArea(named: $0, in: ctx.areas) } ?? proj?.area

        match.project = proj
        match.area = area
        match.heading = nil
        match.isInInbox = area == nil && proj == nil
        match.updatedAt = .now
        try? ctx.modelContext.save()

        return AgentResponse(message: message, affectedTaskIDs: [match.id])
    }

    // MARK: - Action: Schedule Task

    private func doScheduleTask(searchText: String, date: String, message: String, ctx: AgentContext) -> AgentResponse {
        let active = ctx.tasks.filter { $0.status == .active }
        guard let match = bestMatch(for: searchText, in: active) else {
            return AgentResponse(message: "Couldn't find a task matching \"\(searchText)\"")
        }
        guard let whenDate = parseDate(date) else {
            return AgentResponse(message: "Couldn't understand the date \"\(date)\"")
        }
        match.whenDate = whenDate
        match.updatedAt = .now
        try? ctx.modelContext.save()
        return AgentResponse(message: message, affectedTaskIDs: [match.id])
    }

    // MARK: - Action: Defer Task

    private func doDeferTask(searchText: String, message: String, ctx: AgentContext) -> AgentResponse {
        let active = ctx.tasks.filter { $0.status == .active }
        guard let match = bestMatch(for: searchText, in: active) else {
            return AgentResponse(message: "Couldn't find a task matching \"\(searchText)\"")
        }
        match.status = .someday
        match.whenDate = nil
        match.updatedAt = .now
        try? ctx.modelContext.save()
        return AgentResponse(message: message, affectedTaskIDs: [match.id])
    }

    // MARK: - Action: Create Calendar Event

    private func doCreateEvent(title: String, startString: String?, endString: String?, location: String?, message: String, ctx: AgentContext) async -> AgentResponse {
        guard let calendarStore = ctx.calendarStore else {
            return AgentResponse(message: "Calendar access is not available.")
        }

        guard let startStr = startString, let startDate = parseDatetime(startStr) else {
            return AgentResponse(message: "Couldn't understand the event time. Please try again with a specific date and time.")
        }

        let endDate: Date
        if let endStr = endString, let parsed = parseDatetime(endStr) {
            endDate = parsed
        } else {
            endDate = startDate.addingTimeInterval(3600)
        }

        do {
            let event = try await calendarStore.createEvent(title: title, startDate: startDate, endDate: endDate, location: location)
            let card = EventCard(id: event.id, title: event.title, startDate: event.startDate, endDate: event.endDate, location: event.location, isAllDay: false)
            return AgentResponse(message: message, eventCards: [card])
        } catch {
            print("[TaskAgent] Failed to create calendar event: \(error)")
            return AgentResponse(message: "Failed to create calendar event: \(error.localizedDescription)")
        }
    }

    // MARK: - Action: List Tasks

    private func doListTasks(filter: String, message: String, ctx: AgentContext) -> AgentResponse {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let active = ctx.tasks.filter { $0.status == .active }

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
                return AgentResponse(message: message)
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
            filtered = ctx.tasks.filter { $0.status == .someday }
        case "done":
            filtered = Array(ctx.tasks.filter(\.isCompleted)
                .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
                .prefix(10))
        default:
            if let project = findProject(named: filter, in: ctx.projects) {
                filtered = project.taskList.filter { !$0.isCompleted }
            } else if let area = findArea(named: filter, in: ctx.areas) {
                let areaTasks = ctx.tasks.filter { $0.area?.id == area.id || $0.project?.area?.id == area.id }
                filtered = areaTasks.filter { !$0.isCompleted }
            } else {
                filtered = active.filter { $0.title.localizedCaseInsensitiveContains(filter) }
            }
        }

        // Build event cards for calendar-related filters
        let eventCards: [EventCard]?
        let filterLower = filter.lowercased()
        if filterLower == "today" || filterLower == "tomorrow" || filterLower == "upcoming" {
            let matchingEvents: [CalendarEvent]
            if filterLower == "today" {
                matchingEvents = ctx.calendarEvents.filter { calendar.isDateInToday($0.startDate) }
            } else if filterLower == "tomorrow" {
                matchingEvents = ctx.calendarEvents.filter { calendar.isDateInTomorrow($0.startDate) }
            } else {
                matchingEvents = ctx.calendarEvents
            }
            eventCards = matchingEvents.isEmpty ? nil : matchingEvents.map { event in
                EventCard(id: event.id, title: event.title, startDate: event.startDate, endDate: event.endDate, location: event.location, isAllDay: event.isAllDay)
            }
        } else {
            eventCards = nil
        }

        if filtered.isEmpty && eventCards == nil {
            print("[TaskAgent] doListTasks: no local tasks matched filter '\(filter)'")
            return AgentResponse(message: message)
        }

        let cards: [TaskCard]? = filtered.isEmpty ? nil : Array(filtered.prefix(15).map { task in
            TaskCard(
                id: task.id, title: task.title, project: task.project?.title,
                area: task.area?.title, whenDate: task.whenDate,
                deadline: task.deadline, isCompleted: task.isCompleted
            )
        })
        print("[TaskAgent] doListTasks: returning \(cards?.count ?? 0) task cards, \(eventCards?.count ?? 0) event cards")
        return AgentResponse(message: message, affectedTaskIDs: filtered.map(\.id), taskCards: cards, eventCards: eventCards)
    }

    // MARK: - Keyword Fallback (no API key)

    private func keywordFallback(input: String, ctx: AgentContext) -> AgentResponse {
        let lowered = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let active = ctx.tasks.filter { $0.status == .active }

        if lowered.contains("inbox") {
            return listResponse("Inbox", tasks: active.filter(\.isInInbox))
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
            let done = Array(ctx.tasks.filter(\.isCompleted).sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }.prefix(10))
            return listResponse("Done (recent)", tasks: done)
        }

        for project in ctx.projects {
            if lowered.contains(project.title.lowercased()) {
                return listResponse(project.title, tasks: project.taskList.filter { !$0.isCompleted })
            }
        }
        for area in ctx.areas {
            if lowered.contains(area.title.lowercased()) {
                let areaTasks = ctx.tasks.filter { ($0.area?.id == area.id || $0.project?.area?.id == area.id) && !$0.isCompleted }
                return listResponse(area.title, tasks: areaTasks)
            }
        }

        if lowered.hasPrefix("add ") || lowered.hasPrefix("create ") {
            let prefixLen = lowered.hasPrefix("add ") ? 4 : 7
            let title = String(input.dropFirst(prefixLen)).trimmingCharacters(in: .whitespaces)
            if !title.isEmpty {
                let task = TaskItem(title: title, status: .active, isInInbox: true)
                ctx.modelContext.insert(task)
                try? ctx.modelContext.save()
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

    // MARK: - Plan Day Response

    private func buildPlanDayResponse(message: String, ctx: AgentContext) -> AgentResponse {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let active = ctx.tasks.filter { $0.status == .active }

        // Today's tasks
        let todayTasks = active.filter {
            guard let d = $0.effectiveDate else { return false }
            return cal.isDateInToday(d)
        }

        // Overdue tasks
        let overdueTasks = active.filter {
            guard let d = $0.effectiveDate else { return false }
            return d < today
        }

        // Inbox tasks (unsorted)
        let inboxTasks = active.filter(\.isInInbox)

        // Combine: overdue first, then today, then inbox
        var allRelevant: [TaskItem] = []
        allRelevant.append(contentsOf: overdueTasks)
        allRelevant.append(contentsOf: todayTasks)
        allRelevant.append(contentsOf: inboxTasks.filter { t in
            !overdueTasks.contains(where: { $0.id == t.id }) &&
            !todayTasks.contains(where: { $0.id == t.id })
        })

        let taskCards: [TaskCard]? = allRelevant.isEmpty ? nil : Array(allRelevant.prefix(15).map { task in
            TaskCard(
                id: task.id, title: task.title, project: task.project?.title,
                area: task.area?.title, whenDate: task.whenDate,
                deadline: task.deadline, isCompleted: task.isCompleted
            )
        })

        // Today's calendar events
        let todayEvents = ctx.calendarEvents.filter { cal.isDateInToday($0.startDate) }
        let eventCards: [EventCard]? = todayEvents.isEmpty ? nil : todayEvents.map { event in
            EventCard(id: event.id, title: event.title, startDate: event.startDate, endDate: event.endDate, location: event.location, isAllDay: event.isAllDay)
        }

        return AgentResponse(
            message: message,
            affectedTaskIDs: allRelevant.map(\.id),
            taskCards: taskCards,
            eventCards: eventCards,
            isPlanDay: true
        )
    }

    // MARK: - Card Matching for Query/Chat Responses

    private func matchCalendarEvents(message: String, calendarEvents: [CalendarEvent]) -> [EventCard] {
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

    private func parseDatetime(_ string: String) -> Date? {
        // ISO 8601 with timezone
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: string) { return date }

        // ISO 8601 without timezone (YYYY-MM-DDTHH:mm:ss)
        let localIso = DateFormatter()
        localIso.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        localIso.timeZone = .current
        if let date = localIso.date(from: string) { return date }

        // YYYY-MM-DD HH:mm
        let spaceFmt = DateFormatter()
        spaceFmt.dateFormat = "yyyy-MM-dd HH:mm"
        spaceFmt.timeZone = .current
        if let date = spaceFmt.date(from: string) { return date }

        // Fall back to date-only parsing
        return parseDate(string)
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

    private func buildSystemPrompt(ctx: AgentContext) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd (EEEE)"
        let todayStr = fmt.string(from: Date())

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"

        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "h:mm a"

        let completedTasks = ctx.tasks.filter { $0.isCompleted }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        let somedayTasksList = ctx.tasks.filter { $0.status == .someday }

        return GeminiPromptBuilder.buildSystemPrompt(
            areas: ctx.areas.map { (name: $0.title, symbol: $0.symbolName) },
            projects: ctx.projects.map { (name: $0.title, areaName: $0.area?.title) },
            activeTasks: ctx.tasks.filter { $0.status == .active }.map { task in
                (
                    title: task.title,
                    project: task.project?.title,
                    area: task.area?.title,
                    whenDate: task.whenDate.map { dateFmt.string(from: $0) },
                    deadline: task.deadline.map { dateFmt.string(from: $0) },
                    isInInbox: task.isInInbox,
                    locationName: task.locationName
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
            calendarEvents: ctx.calendarEvents.map { event in
                (
                    title: event.title,
                    date: dateFmt.string(from: event.startDate),
                    start: timeFmt.string(from: event.startDate),
                    end: timeFmt.string(from: event.endDate),
                    location: event.location
                )
            },
            todayDate: todayStr,
            userLocation: ctx.locationService?.locationSummary
        )
    }
}
