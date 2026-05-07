//
//  Tag.swift
//  FluxWatch
//
//  Created by Spencer Dearman.
//

import Foundation
import SwiftData

// MARK: - Tag

/// A user-defined label that can be assigned to tasks for categorization.
@Model
final class Tag {

    // MARK: Properties

    var id: UUID = UUID()
    var title: String = ""
    var symbolName: String = "tag"
    var tintHex: String = "#8897AA"

    // MARK: Relationships

    @Relationship(deleteRule: .cascade, inverse: \TaskTagAssignment.tag)
    var taskAssignments: [TaskTagAssignment]?

    // MARK: Initialization

    init(
        id: UUID = UUID(),
        title: String,
        symbolName: String = "tag",
        tintHex: String = "#8897AA"
    ) {
        self.id = id
        self.title = title
        self.symbolName = symbolName
        self.tintHex = tintHex
    }
}
