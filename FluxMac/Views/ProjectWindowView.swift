//
//  ProjectWindowView.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

struct ProjectWindowView: View {
    let projectID: UUID?
    
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @State private var expandedTaskID: UUID?
    @State private var completingTaskIDs: Set<UUID> = []
    
    var body: some View {
        Group {
            if let project = projects.first(where: { $0.id == projectID }) {
                ProjectDetailView(
                    project: project,
                    expandedTaskID: $expandedTaskID,
                    completingTaskIDs: $completingTaskIDs
                )
                .padding(24)
                .background {
                    AppBackground()
                }
            } else {
                ContentUnavailableView("Project unavailable", systemImage: "square.stack.3d.up.slash")
            }
        }
        .frame(minWidth: 760, minHeight: 640)
    }
}
