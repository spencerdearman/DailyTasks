//
//  GeminiService.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import Foundation

// MARK: - Gemini Structured Response

struct GeminiActionResponse: Codable {
    let action: String
    let title: String?
    let notes: String?
    let searchText: String?
    let targetProject: String?
    let targetArea: String?
    let date: String?
    let filter: String?
    let message: String?
    let subtasks: [String]?

    enum CodingKeys: String, CodingKey {
        case action
        case title
        case notes
        case searchText = "search_text"
        case targetProject = "target_project"
        case targetArea = "target_area"
        case date
        case filter
        case message
        case subtasks
    }
}

// MARK: - Conversation Message

struct GeminiMessage {
    let role: String // "user" or "model"
    let text: String
}

// MARK: - GeminiService

actor GeminiService {
    private let model = "gemini-2.5-flash"
    private var conversationHistory: [GeminiMessage] = []

    // JSON schema for structured output
    private let responseSchema: [String: Any] = [
        "type": "OBJECT",
        "properties": [
            "action": [
                "type": "STRING",
                "enum": [
                    "create_task", "complete_task", "move_task", "schedule_task",
                    "defer_task", "list_tasks", "decompose_task", "plan_day",
                    "reschedule_overdue", "query", "chat"
                ]
            ],
            "title": ["type": "STRING", "description": "Task title for create_task, or goal for decompose_task"],
            "notes": ["type": "STRING", "description": "Task notes or description"],
            "search_text": ["type": "STRING", "description": "Text to fuzzy-match an existing task"],
            "target_project": ["type": "STRING", "description": "Project name to assign/move to"],
            "target_area": ["type": "STRING", "description": "Area name to assign/move to"],
            "date": ["type": "STRING", "description": "Date: today, tomorrow, next week, monday-sunday, or YYYY-MM-DD"],
            "filter": ["type": "STRING", "description": "For list_tasks: inbox, today, tomorrow, upcoming, open, later, done, or a search query"],
            "message": ["type": "STRING", "description": "Natural language response to show the user"],
            "subtasks": [
                "type": "ARRAY",
                "items": ["type": "STRING"],
                "description": "For decompose_task: list of suggested subtask titles"
            ]
        ],
        "required": ["action", "message"]
    ]

    func send(_ input: String, apiKey: String, systemPrompt: String) async throws -> GeminiActionResponse {
        print("[GeminiService] send() called with input: \"\(input)\"")
        conversationHistory.append(GeminiMessage(role: "user", text: input))

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!

        // Build contents array from conversation history
        var contents: [[String: Any]] = []
        for msg in conversationHistory {
            contents.append([
                "role": msg.role,
                "parts": [["text": msg.text]]
            ])
        }

        let requestBody: [String: Any] = [
            "system_instruction": [
                "parts": [["text": systemPrompt]]
            ],
            "contents": contents,
            "generationConfig": [
                "response_mime_type": "application/json",
                "response_schema": responseSchema,
                "temperature": 0.3
            ]
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        print("[GeminiService] Request body size: \(jsonData.count) bytes, sending POST...")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)
        print("[GeminiService] Response received, data size: \(data.count) bytes")

        guard let httpResponse = response as? HTTPURLResponse else {
            print("[GeminiService] ERROR: Not an HTTP response")
            throw GeminiError.invalidResponse
        }

        print("[GeminiService] HTTP status: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            print("[GeminiService] ERROR response body: \(body.prefix(500))")
            throw GeminiError.apiError(statusCode: httpResponse.statusCode, message: body)
        }

        // Parse Gemini response structure
        let geminiResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let candidates = geminiResponse?["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            print("[GeminiService] ERROR: Could not parse candidates/content/parts")
            let rawBody = String(data: data, encoding: .utf8) ?? "unparseable"
            print("[GeminiService] Raw response: \(rawBody.prefix(1000))")
            throw GeminiError.noContent
        }

        print("[GeminiService] Parsed text from Gemini: \(text.prefix(300))")

        // Parse the structured JSON from the text
        guard let textData = text.data(using: .utf8) else {
            throw GeminiError.noContent
        }

        let actionResponse = try JSONDecoder().decode(GeminiActionResponse.self, from: textData)
        print("[GeminiService] Decoded action: \(actionResponse.action), message: \(actionResponse.message ?? "nil")")

        // Add model response to history
        conversationHistory.append(GeminiMessage(role: "model", text: text))

        // Keep history manageable (last 10 messages to avoid timeout)
        if conversationHistory.count > 10 {
            conversationHistory = Array(conversationHistory.suffix(10))
        }

        return actionResponse
    }

    func clearHistory() {
        conversationHistory = []
    }
}

// MARK: - Errors

enum GeminiError: LocalizedError {
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case noContent

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid response from Gemini"
        case .apiError(let code, let msg): return "Gemini API error (\(code)): \(msg)"
        case .noContent: return "No content in Gemini response"
        }
    }
}

// MARK: - System Prompt Builder

enum GeminiPromptBuilder {
    static func buildSystemPrompt(
        areas: [(name: String, symbol: String)],
        projects: [(name: String, areaName: String?)],
        activeTasks: [(title: String, project: String?, area: String?, whenDate: String?, deadline: String?, isInInbox: Bool)],
        completedTasks: [(title: String, completedAt: String?)] = [],
        somedayTasks: [(title: String, project: String?, area: String?)] = [],
        calendarEvents: [(title: String, date: String, start: String, end: String, location: String?)],
        todayDate: String
    ) -> String {
        var prompt = """
        You are Flux Agent, an intelligent assistant built into the Flux task manager app. \
        Today's date is \(todayDate). \
        You help users manage their tasks through natural conversation.

        AVAILABLE ACTIONS:
        - create_task: Create a new task. Set title, notes, date, target_project, target_area as needed. \
        Parse natural language dates (e.g. "Tuesday" → the next Tuesday as YYYY-MM-DD, "next week" → next Monday). \
        Infer the best area/project from context.
        - complete_task: Mark a task as done. Set search_text to match the task title.
        - move_task: Move a task to a different project or area. Set search_text + target_project/target_area.
        - schedule_task: Set or change a task's date. Set search_text + date.
        - defer_task: Move a task to "Later" (someday/maybe). Set search_text.
        - list_tasks: Show tasks. Set filter to: inbox, today, tomorrow, upcoming, open, later, done, \
        or a project/area name, or a search query.
        - decompose_task: Break a goal into subtasks. Set title (the goal) and subtasks (array of subtask titles). \
        Generate 3-7 concrete, actionable subtasks.
        - plan_day: Suggest a prioritized plan for today. Look at today's tasks, deadlines, and calendar. \
        Return a message with the suggested order and reasoning.
        - reschedule_overdue: Find overdue tasks and suggest new dates in the message.
        - query: Answer questions about tasks, productivity, workload. Return answer in message.
        - chat: For general conversation or when no action fits. Return response in message.

        RULES:
        - Always set the "message" field with a concise, friendly response to show the user.
        - You can use inline markdown: **bold** for emphasis, *italic* for secondary info. Do NOT use headers (##) or code blocks.
        - CRITICAL: For list_tasks, query, plan_day, and reschedule_overdue actions, you MUST include the actual task names and relevant details directly in the "message" field. The app will show rich cards for tasks and events it can match, but your message text is the primary content the user sees. Always reference specific tasks and events by name.
        - For plan_day and planning queries: analyze the user's calendar gaps and suggest which tasks to work on in each free block. Be specific — name the tasks and time slots. Don't just list tasks generically.
        - For create_task, intelligently categorize into the most appropriate area/project based on content.
        - When the user references a task vaguely, use search_text with the most distinctive words.
        - For dates, always convert to YYYY-MM-DD format or use: today, tomorrow, next week.
        - Keep messages brief — 1-2 sentences for actions, more detail for queries/planning.
        - If the user's intent is ambiguous, prefer the most helpful interpretation.
        - If the user asks about tasks and there are none matching, say so explicitly (e.g. "You have no tasks scheduled for tomorrow.").

        """

        // Areas
        if !areas.isEmpty {
            let areaList = areas.map { "\($0.name) (\($0.symbol))" }.joined(separator: ", ")
            prompt += "\nAREAS: \(areaList)"
        }

        // Projects
        if !projects.isEmpty {
            let projList = projects.map { p in
                p.areaName != nil ? "\(p.name) (in \(p.areaName!))" : p.name
            }.joined(separator: ", ")
            prompt += "\nPROJECTS: \(projList)"
        }

        // Active tasks
        if !activeTasks.isEmpty {
            prompt += "\n\nACTIVE TASKS:"
            for task in activeTasks.prefix(30) {
                var line = "- \"\(task.title)\""
                if let p = task.project { line += " [project: \(p)]" }
                else if let a = task.area { line += " [area: \(a)]" }
                if task.isInInbox { line += " [inbox]" }
                if let d = task.whenDate { line += " [scheduled: \(d)]" }
                if let dl = task.deadline { line += " [deadline: \(dl)]" }
                prompt += "\n\(line)"
            }
        }

        // Completed tasks
        if !completedTasks.isEmpty {
            prompt += "\n\nCOMPLETED TASKS (recent):"
            for task in completedTasks.prefix(15) {
                var line = "- \"\(task.title)\""
                if let d = task.completedAt { line += " [completed: \(d)]" }
                prompt += "\n\(line)"
            }
        }

        // Someday/Later tasks
        if !somedayTasks.isEmpty {
            prompt += "\n\nLATER/SOMEDAY TASKS:"
            for task in somedayTasks.prefix(15) {
                var line = "- \"\(task.title)\""
                if let p = task.project { line += " [project: \(p)]" }
                else if let a = task.area { line += " [area: \(a)]" }
                prompt += "\n\(line)"
            }
        }

        // Calendar
        if !calendarEvents.isEmpty {
            prompt += "\n\nCALENDAR EVENTS (this week):"
            for event in calendarEvents {
                var line = "- \(event.title) [\(event.date)] \(event.start) – \(event.end)"
                if let loc = event.location, !loc.isEmpty { line += " @ \(loc)" }
                prompt += "\n\(line)"
            }
        }

        return prompt
    }
}
