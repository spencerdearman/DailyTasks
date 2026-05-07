//
//  SemanticRouter.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import Foundation
import NaturalLanguage

// MARK: - SemanticRoutingDecision

/// The result of semantic analysis, containing area inference and scheduling suggestions.
struct SemanticRoutingDecision {
    let matchedArea: Area?
    let suggestedStatus: TaskStatus
    let suggestedWhen: Date?
    let shouldMarkEvening: Bool
}

// MARK: - SemanticRouter

/// Analyzes task text to intelligently route tasks to areas and infer scheduling.
enum SemanticRouter {

    /// Analyzes the title and notes to determine the best area, status, and date.
    static func analyze(title: String, notes: String, areas: [Area]) -> SemanticRoutingDecision {
        let body = [title, notes].joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        let matchedArea = inferArea(for: body, areas: areas)
        let status = inferStatus(for: body)
        let suggestedWhen = inferDate(for: body, status: status)
        let shouldMarkEvening = body.localizedCaseInsensitiveContains("evening")
            || body.localizedCaseInsensitiveContains("tonight")
            || body.localizedCaseInsensitiveContains("after work")

        return SemanticRoutingDecision(
            matchedArea: matchedArea,
            suggestedStatus: status,
            suggestedWhen: suggestedWhen,
            shouldMarkEvening: shouldMarkEvening
        )
    }

    // MARK: Private

    private static func inferArea(for body: String, areas: [Area]) -> Area? {
        guard !body.isEmpty, !areas.isEmpty else { return nil }

        let normalized = body.lowercased()
        if let keywordMatch = areas.first(where: { area in
            let areaCorpus = [area.title, area.notes].joined(separator: " ").lowercased()
            return areaCorpus.split(separator: " ").contains(where: normalized.contains)
        }) {
            return keywordMatch
        }

        guard let embedding = NLEmbedding.sentenceEmbedding(for: .english) else {
            return nil
        }

        var bestArea: Area?
        var bestDistance = Double.greatestFiniteMagnitude

        for area in areas {
            let areaCorpus = [area.title, area.notes].joined(separator: ". ")
            let distance = embedding.distance(between: body, and: areaCorpus)
            if distance < bestDistance {
                bestDistance = distance
                bestArea = area
            }
        }

        return bestDistance < 0.92 ? bestArea : nil
    }

    private static func inferStatus(for body: String) -> TaskStatus {
        let lowered = body.lowercased()
        let somedaySignals = [
            "someday", "maybe", "explore", "brainstorm", "consider",
            "learn", "idea", "wish", "dream", "research"
        ]
        if somedaySignals.contains(where: lowered.contains) {
            return .someday
        }
        return .active
    }

    private static func inferDate(for body: String, status: TaskStatus) -> Date? {
        guard status == .active else { return nil }
        let lowered = body.lowercased()
        let calendar = Calendar.current

        if ["today", "asap", "urgent", "now"].contains(where: lowered.contains) {
            return calendar.startOfDay(for: .now)
        }

        if ["tomorrow", "next"].contains(where: lowered.contains) {
            return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now))
        }

        let actionSignals = [
            "submit", "finish", "call", "send", "book", "pay", "prepare", "review"
        ]
        if actionSignals.contains(where: lowered.contains) {
            return calendar.startOfDay(for: .now)
        }

        return nil
    }
}
