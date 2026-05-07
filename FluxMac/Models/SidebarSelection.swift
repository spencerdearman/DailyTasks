//
//  SidebarSelection.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import Foundation

// MARK: - SidebarSelection

/// Identifies the currently selected item in the navigation sidebar.
enum SidebarSelection: Hashable {
    case inbox
    case today
    case upcoming
    case anytime
    case someday
    case logbook
    case area(UUID)
    case project(UUID)
}
