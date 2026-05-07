//
//  CategorizationService.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import Foundation

// MARK: - CategorizationService

/// Lightweight Gemini-powered service that classifies a task into an Area and/or Project.
///
/// Falls back gracefully when no API key is available.
actor CategorizationService {

    // MARK: Private Properties

    private let model = "gemini-2.5-flash"

    private let schema: [String: Any] = [
        "type": "OBJECT",
        "properties": [
            "area": ["type": "STRING", "description": "Best matching area name, or empty string if none"],
            "project": ["type": "STRING", "description": "Best matching project name, or empty string if none"],
        ],
        "required": ["area", "project"],
    ]

    // MARK: Types

    /// The decoded classification result from the Gemini API.
    struct Classification: Codable {
        let area: String
        let project: String
    }

    // MARK: Public Methods

    /// Classifies a task into the best-matching area and project.
    ///
    /// - Returns: A tuple of optional area/project names. Returns `(nil, nil)` when no match is found.
    func categorize(
        title: String,
        notes: String,
        areas: [(name: String, description: String)],
        projects: [(name: String, areaName: String?)],
        apiKey: String
    ) async -> (area: String?, project: String?) {
        guard !apiKey.isEmpty else { return (nil, nil) }

        let areaList = areas.map { "\($0.name)" }.joined(separator: ", ")
        let projList = projects.map { p in
            p.areaName != nil ? "\(p.name) (in \(p.areaName!))" : p.name
        }.joined(separator: ", ")

        let prompt = """
        Classify this task into the best Area and Project.

        Task title: "\(title)"
        \(notes.isEmpty ? "" : "Notes: \"\(notes)\"")

        Available Areas: \(areaList.isEmpty ? "none" : areaList)
        Available Projects: \(projList.isEmpty ? "none" : projList)

        Rules:
        - Pick the SINGLE best area. If none fit, return empty string.
        - Pick the SINGLE best project. If none fit, return empty string.
        - Use exact names from the lists above.
        - Be conservative — only classify if confident.
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
            print("[CategorizationService] Error: \(error.localizedDescription)")
            return (nil, nil)
        }
    }
}
