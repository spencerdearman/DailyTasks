//
//  ProjectCard.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import SwiftUI

// MARK: - ProjectCard

/// A summary card showing a project's title, goal, and active task count.
struct ProjectCard: View {
    let project: Project

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(project.title)
                    .font(.headline)
                Text(project.goalSummary)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(project.activeTaskCount) active")
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
