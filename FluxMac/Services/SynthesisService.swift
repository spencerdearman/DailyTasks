//
//  SynthesisService.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import Foundation
import SwiftData

// MARK: - SynthesisService

/// Generates a daily "State of the Union" briefing using the Gemini API.
actor SynthesisService {

    // MARK: Private Properties

    private let model = "gemini-2.5-flash"

    private let schema: [String: Any] = [
        "type": "OBJECT",
        "properties": [
            "greeting": [
                "type": "STRING",
                "description": "A brief, motivational good-morning greeting (1 sentence)",
            ],
            "conflicts": [
                "type": "ARRAY",
                "items": ["type": "STRING"],
                "description": "List of scheduling conflicts or warnings (overlapping events, double-bookings, overdue deadlines)",
            ],
            "suggested_plan": [
                "type": "STRING",
                "description": "A time-blocked suggested plan for the day in markdown. Use **bold** for task names and *italic* for time slots. Keep it concise — 5-8 lines max.",
            ],
        ],
        "required": ["greeting", "conflicts", "suggested_plan"],
    ]

    // MARK: Types

    /// The decoded synthesis response from the Gemini API.
    struct SynthesisResponse: Codable {
        let greeting: String
        let conflicts: [String]
        let suggestedPlan: String

        enum CodingKeys: String, CodingKey {
            case greeting
            case conflicts
            case suggestedPlan = "suggested_plan"
        }
    }

    // MARK: Public Methods

    /// Generates a morning briefing from the user's tasks, calendar, and recent completions.
    func generate(
        activeTasks: [TaskItem],
        calendarEvents: [CalendarEvent],
        areas: [Area],
        completedYesterday: [TaskItem],
        apiKey: String
    ) async throws -> SynthesisResponse {
        guard !apiKey.isEmpty else {
            throw SynthesisError.noAPIKey
        }

        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "h:mm a"
        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "EEEE, MMMM d"

        // Gather context
        let overdueTasks = activeTasks.filter {
            guard let d = $0.effectiveDate else { return false }
            return d < today
        }
        let todayTasks = activeTasks.filter {
            guard let d = $0.effectiveDate else { return false }
            return cal.isDateInToday(d)
        }
        let todayEvents = calendarEvents.filter { cal.isDateInToday($0.startDate) }
        let tomorrowEvents = calendarEvents.filter { cal.isDateInTomorrow($0.startDate) }
        let inboxTasks = activeTasks.filter(\.isInInbox)

        var prompt = """
        Today is \(dayFmt.string(from: .now)). Generate a morning briefing for the user.

        """

        if !overdueTasks.isEmpty {
            prompt += "\nOVERDUE TASKS (\(overdueTasks.count)):"
            for t in overdueTasks.prefix(10) {
                prompt += "\n- \"\(t.title)\" (was due \(t.effectiveDate.map { dateFmt.string(from: $0) } ?? "unknown"))"
            }
        }

        if !todayTasks.isEmpty {
            prompt += "\n\nTODAY'S TASKS (\(todayTasks.count)):"
            for t in todayTasks.prefix(15) {
                var line = "- \"\(t.title)\""
                if let p = t.project?.title { line += " [project: \(p)]" }
                if let loc = t.locationName { line += " [at: \(loc)]" }
                prompt += "\n\(line)"
            }
        }

        if !todayEvents.isEmpty {
            prompt += "\n\nTODAY'S CALENDAR (\(todayEvents.count)):"
            for e in todayEvents {
                var line = "- \(e.title) \(timeFmt.string(from: e.startDate)) – \(timeFmt.string(from: e.endDate))"
                if let loc = e.location, !loc.isEmpty { line += " @ \(loc)" }
                prompt += "\n\(line)"
            }
        }

        if !tomorrowEvents.isEmpty {
            prompt += "\n\nTOMORROW'S CALENDAR (\(tomorrowEvents.count)):"
            for e in tomorrowEvents.prefix(5) {
                prompt += "\n- \(e.title) \(timeFmt.string(from: e.startDate)) – \(timeFmt.string(from: e.endDate))"
            }
        }

        if !inboxTasks.isEmpty {
            prompt += "\n\nUNSORTED INBOX (\(inboxTasks.count) tasks)"
        }

        if !completedYesterday.isEmpty {
            prompt += "\n\nCOMPLETED YESTERDAY: \(completedYesterday.count) tasks"
        }

        prompt += """

        \nINSTRUCTIONS:
        - Generate a brief, encouraging greeting (1 sentence).
        - List any scheduling conflicts (overlapping events, overdue tasks with today's deadlines, etc.).
        - Create a time-blocked suggested plan that fits tasks around calendar events.
        - Suggest which overdue tasks to tackle first and which to reschedule.
        - Be concise and actionable. Use **bold** for task names.
        """

        let requestBody: [String: Any] = [
            "system_instruction": [
                "parts": [["text": "You are a productivity assistant generating a morning briefing. Be concise, warm, and actionable."]],
            ],
            "contents": [
                ["role": "user", "parts": [["text": prompt]]],
            ],
            "generationConfig": [
                "response_mime_type": "application/json",
                "response_schema": schema,
                "temperature": 0.4,
            ],
        ]

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            throw SynthesisError.apiError(body)
        }

        let geminiResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let candidates = geminiResponse?["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String,
              let textData = text.data(using: .utf8) else {
            throw SynthesisError.parseError
        }

        return try JSONDecoder().decode(SynthesisResponse.self, from: textData)
    }
}

// MARK: - SynthesisError

/// Errors that can occur during daily synthesis generation.
enum SynthesisError: LocalizedError {
    case noAPIKey
    case apiError(String)
    case parseError

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "No Gemini API key configured"
        case .apiError(let msg): return "Synthesis API error: \(msg)"
        case .parseError: return "Failed to parse synthesis response"
        }
    }
}
