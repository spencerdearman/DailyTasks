//
//  TaskStatus.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import Foundation

// MARK: - TaskStatus

/// Represents the lifecycle state of a task within the Flux system.
enum TaskStatus: String, Codable, CaseIterable, Identifiable {
    case active
    case someday
    case completed

    var id: String { rawValue }
}
