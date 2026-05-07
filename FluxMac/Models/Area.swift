//
//  Area.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import Foundation
import SwiftData

// MARK: - Area

/// A top-level organizational container representing a life area (e.g., Work, Health).
@Model
final class Area {

    // MARK: Properties

    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var symbolName: String = "square.grid.2x2"
    var tintHex: String = "#5B83B7"
    var sortOrder: Double = 0

    // MARK: Relationships

    @Relationship(deleteRule: .cascade, inverse: \Project.area)
    var projects: [Project]?

    @Relationship(deleteRule: .nullify, inverse: \TaskItem.area)
    var tasks: [TaskItem]?

    // MARK: Initialization

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        symbolName: String = "square.grid.2x2",
        tintHex: String = "#5B83B7",
        sortOrder: Double = 0
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.symbolName = symbolName
        self.tintHex = tintHex
        self.sortOrder = sortOrder
        self.projects = []
        self.tasks = []
    }
}
