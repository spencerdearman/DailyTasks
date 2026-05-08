//
//  AgentConversation.swift
//  TetherMac
//
//  Created by Spencer Dearman.
//

import Foundation
import SwiftData

// MARK: - ConversationMessage

/// A single message in an agent conversation, serialized as JSON inside AgentConversation.
struct ConversationMessage: Codable {
    enum Role: String, Codable { case user, assistant }

    let role: Role
    let text: String
    let taskCardsJSON: String?
    let eventCardsJSON: String?
    let subtasksJSON: String?
    let isPlanDay: Bool
    let timestamp: Date
}

// MARK: - AgentConversation

/// A persisted agent conversation for the temporal scrubber. Auto-pruned after 48 hours.
@Model
final class AgentConversation {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var firstQuery: String = ""
    var messagesJSON: String = "[]"

    init(firstQuery: String) {
        self.id = UUID()
        self.createdAt = Date()
        self.updatedAt = Date()
        self.firstQuery = firstQuery
        self.messagesJSON = "[]"
    }

    // MARK: Helpers

    func decodeMessages() -> [ConversationMessage] {
        guard let data = messagesJSON.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([ConversationMessage].self, from: data)) ?? []
    }

    func appendMessage(_ message: ConversationMessage) {
        var messages = decodeMessages()
        messages.append(message)
        if let data = try? JSONEncoder().encode(messages),
           let json = String(data: data, encoding: .utf8) {
            messagesJSON = json
            updatedAt = Date()
        }
    }
}
