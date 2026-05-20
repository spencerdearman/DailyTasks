//
//  ProjectEditSheet.swift
//  TetherMac
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

// MARK: - ProjectEditSheet

/// A modal form for editing an existing project's properties.
struct ProjectEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Area.sortOrder) private var areas: [Area]

    @Bindable var project: Project

    @State private var title: String
    @State private var notes: String
    @State private var goalSummary: String
    @State private var selectedAreaID: UUID?
    @State private var tintHex: String

    private let tintOptions = [
        "#E74C3C", "#E67E22", "#F1C40F", "#2ECC71", "#3498DB", "#6C5CE7", "#9B59B6",
        "#5B83B7", "#62666D", "#8E8E93", "#7A7068"
    ]

    init(project: Project) {
        self.project = project
        _title = State(initialValue: project.title)
        _notes = State(initialValue: project.notes)
        _goalSummary = State(initialValue: project.goalSummary)
        _selectedAreaID = State(initialValue: project.area?.id)
        _tintHex = State(initialValue: project.tintHex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Edit Project")
                .font(.title2.weight(.semibold))

            TextField("Project name", text: $title)
                .textFieldStyle(.roundedBorder)
                .font(.title3)

            TextField("Goal or description (optional)", text: $notes)
                .textFieldStyle(.roundedBorder)

            Picker("Area", selection: $selectedAreaID) {
                Text("No area").tag(UUID?.none)
                ForEach(areas) { area in
                    Text(area.title).tag(Optional(area.id))
                }
            }

            HStack(spacing: 8) {
                Text("Color")
                    .font(.subheadline.weight(.medium))
                ForEach(tintOptions, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 24, height: 24)
                        .overlay {
                            if tintHex == hex {
                                Circle().stroke(Color.primary, lineWidth: 2)
                            }
                        }
                        .onTapGesture { tintHex = hex }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button("Save") {
                    saveProject()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(.ultraThinMaterial)
    }

    private func saveProject() {
        project.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        project.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        project.goalSummary = goalSummary.trimmingCharacters(in: .whitespacesAndNewlines)
        project.tintHex = tintHex
        project.area = areas.first(where: { $0.id == selectedAreaID })
        try? modelContext.save()
        dismiss()
    }
}
