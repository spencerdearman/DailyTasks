//
//  Tag.swift
//  FluxMac
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

    // MARK: Color Palette

    static let colorPalette: [String] = [
        "#E8574A", "#E8953A", "#E5C445", "#5BBD6B",
        "#46A0D5", "#9B6FD1", "#D96BA0", "#6BC4C4"
    ]

    /// Returns a color from the palette using modular indexing.
    static func nextColor(forIndex index: Int) -> String {
        colorPalette[index % colorPalette.count]
    }

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
