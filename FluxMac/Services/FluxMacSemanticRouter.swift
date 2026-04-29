//
//  FluxMacSemanticRouter.swift
//  FluxMac
//
//  Created by OpenAI.
//

import Foundation
import NaturalLanguage

struct FluxSemanticRoutingDecision {
    let matchedArea: FluxArea?
    let suggestedStatus: FluxTaskStatus
    let suggestedWhen: Date?
    let shouldMarkEvening: Bool
}

enum FluxSemanticRouter {
    static func analyze(title: String, notes: String, areas: [FluxArea]) -> FluxSemanticRoutingDecision {
        let body = [title, notes].joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        let matchedArea = inferArea(for: body, areas: areas)
        let status = inferStatus(for: body)
        let suggestedWhen = inferDate(for: body, status: status)
        let shouldMarkEvening = body.localizedCaseInsensitiveContains("evening")
            || body.localizedCaseInsensitiveContains("tonight")
            || body.localizedCaseInsensitiveContains("after work")

        return FluxSemanticRoutingDecision(
            matchedArea: matchedArea,
            suggestedStatus: status,
            suggestedWhen: suggestedWhen,
            shouldMarkEvening: shouldMarkEvening
        )
    }

    private static func inferArea(for body: String, areas: [FluxArea]) -> FluxArea? {
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

        var bestArea: FluxArea?
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

    private static func inferStatus(for body: String) -> FluxTaskStatus {
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

    private static func inferDate(for body: String, status: FluxTaskStatus) -> Date? {
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
