//
//  CategorizationService.swift
//  TetherApp
//
//  Created by Spencer Dearman.
//

import Foundation

// MARK: - CategorizationService

/// Lightweight Gemini-powered service that classifies a task into an Area and/or Project.
actor CategorizationService {

    private let model = "gemini-2.5-flash"

    private let schema: [String: Any] = [
        "type": "OBJECT",
        "properties": [
            "area": ["type": "STRING", "description": "Best matching area name, or empty string if none"],
            "project": ["type": "STRING", "description": "Best matching project name, or empty string if none"],
        ],
        "required": ["area", "project"],
    ]

    private let bulkSchema: [String: Any] = [
        "type": "OBJECT",
        "properties": [
            "classifications": [
                "type": "ARRAY",
                "items": [
                    "type": "OBJECT",
                    "properties": [
                        "index": ["type": "INTEGER", "description": "Zero-based index of the task in the input list"],
                        "area": ["type": "STRING", "description": "Best matching area name, or empty string if none"],
                        "project": ["type": "STRING", "description": "Best matching project name, or empty string if none"],
                    ],
                    "required": ["index", "area", "project"],
                ],
            ],
        ],
        "required": ["classifications"],
    ]

    struct Classification: Codable {
        let area: String
        let project: String
    }

    struct BulkClassification: Codable {
        let index: Int
        let area: String
        let project: String
    }

    struct BulkResult: Codable {
        let classifications: [BulkClassification]
    }

    func categorize(
        title: String,
        notes: String,
        areas: [(name: String, description: String)],
        projects: [(name: String, areaName: String?)],
        apiKey: String
    ) async -> (area: String?, project: String?) {
        guard !apiKey.isEmpty else { return (nil, nil) }

        let areaList = areas.map { "\($0.name) — \($0.description)" }.joined(separator: "\n")
        let projList = projects.map { p in
            p.areaName != nil ? "\(p.name) (in \(p.areaName!))" : p.name
        }.joined(separator: ", ")

        let prompt = """
        Classify this task into the best Area and Project.

        Task title: "\(title)"
        \(notes.isEmpty ? "" : "Notes: \"\(notes)\"")

        Available Areas:
        \(areaList.isEmpty ? "none" : areaList)

        Available Projects: \(projList.isEmpty ? "none" : projList)

        Rules:
        - Pick the SINGLE best area. If none fit, return empty string.
        - Pick the SINGLE best project. If none fit, return empty string.
        - Use exact names from the lists above.
        - Always pick an area if there's a reasonable match — most tasks fit somewhere.
        """

        let requestBody: [String: Any] = [
            "system_instruction": [
                "parts": [["text": "You classify tasks into areas and projects. Return JSON only."]],
            ],
            "contents": [
                ["role": "user", "parts": [["text": prompt]]],
            ],
            "generationConfig": [
                "response_mime_type": "application/json",
                "response_schema": schema,
                "temperature": 0.1,
            ],
        ]

        do {
            let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            request.timeoutInterval = 15

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return (nil, nil)
            }

            let geminiResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let candidates = geminiResponse?["candidates"] as? [[String: Any]],
                  let content = candidates.first?["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let text = parts.first?["text"] as? String,
                  let textData = text.data(using: .utf8) else {
                return (nil, nil)
            }

            let classification = try JSONDecoder().decode(Classification.self, from: textData)
            return (
                area: classification.area.isEmpty ? nil : classification.area,
                project: classification.project.isEmpty ? nil : classification.project
            )
        } catch {
            return (nil, nil)
        }
    }

    /// Classify multiple tasks in a single API call for efficiency.
    func categorizeBulk(
        tasks: [(title: String, notes: String)],
        areas: [(name: String, description: String)],
        projects: [(name: String, areaName: String?)],
        apiKey: String
    ) async -> [(area: String?, project: String?)] {
        guard !apiKey.isEmpty, !tasks.isEmpty else {
            return Array(repeating: (nil, nil), count: tasks.count)
        }

        let areaList = areas.map { "\($0.name) — \($0.description)" }.joined(separator: "\n")
        let projList = projects.map { p in
            p.areaName != nil ? "\(p.name) (in \(p.areaName!))" : p.name
        }.joined(separator: ", ")

        var taskList = ""
        for (i, task) in tasks.enumerated() {
            taskList += "\(i). \"\(task.title)\""
            if !task.notes.isEmpty { taskList += " — \(task.notes)" }
            taskList += "\n"
        }

        let prompt = """
        Classify each task below into the best Area and optionally a Project.

        TASKS:
        \(taskList)
        Available Areas:
        \(areaList.isEmpty ? "none" : areaList)

        Available Projects: \(projList.isEmpty ? "none" : projList)

        Rules:
        - For each task, pick the SINGLE best area. Most tasks should fit into an area — only return empty string if it truly doesn't match anything.
        - Optionally pick the best project if one fits. If no project fits, return empty string.
        - Use exact area and project names from the lists above.
        - Return a classification for every task (indices 0 through \(tasks.count - 1)).
        """

        let requestBody: [String: Any] = [
            "system_instruction": [
                "parts": [["text": "You classify tasks into areas and projects. Return JSON only."]],
            ],
            "contents": [
                ["role": "user", "parts": [["text": prompt]]],
            ],
            "generationConfig": [
                "response_mime_type": "application/json",
                "response_schema": bulkSchema,
                "temperature": 0.1,
            ],
        ]

        do {
            let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)")!
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            request.timeoutInterval = 30

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("[CategorizationService] Bulk API error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return Array(repeating: (nil, nil), count: tasks.count)
            }

            let geminiResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let candidates = geminiResponse?["candidates"] as? [[String: Any]],
                  let content = candidates.first?["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let text = parts.first(where: { $0["thought"] as? Bool != true })?["text"] as? String,
                  let textData = text.data(using: .utf8) else {
                print("[CategorizationService] Bulk parse error: couldn't extract text")
                return Array(repeating: (nil, nil), count: tasks.count)
            }

            let result = try JSONDecoder().decode(BulkResult.self, from: textData)

            // Build results array indexed by task position
            var results = Array(repeating: (area: String?(nil), project: String?(nil)), count: tasks.count)
            for c in result.classifications where c.index >= 0 && c.index < tasks.count {
                results[c.index] = (
                    area: c.area.isEmpty ? nil : c.area,
                    project: c.project.isEmpty ? nil : c.project
                )
            }
            return results
        } catch {
            print("[CategorizationService] Bulk error: \(error)")
            return Array(repeating: (nil, nil), count: tasks.count)
        }
    }
}
