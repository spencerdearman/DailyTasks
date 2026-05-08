//
//  NewProjectSheet.swift
//  FluxApp
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

// MARK: - NewProjectSheet

/// A sheet for creating a new project with an optional area assignment and tint color.
struct NewProjectSheet: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // MARK: - Queries

    @Query(sort: \Area.sortOrder) private var areas: [Area]

    // MARK: - State

    @State private var title = ""
    @State private var notes = ""
    @State private var selectedAreaID: UUID?
    @State private var tintHex = "#3B82F6"
    @State private var showCustomColorPicker = false
    @State private var customColor = Color.blue

    // MARK: - Constants

    private let tintOptions = [
        "#3B82F6", // blue
        "#8B5CF6", // purple
        "#EC4899", // pink
        "#EF4444", // red
        "#F59E0B", // amber
        "#10B981", // emerald
        "#06B6D4", // cyan
        "#6366F1", // indigo
    ]

    // MARK: - Computed

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    // Name & Description
                    VStack(alignment: .leading, spacing: 0) {
                        TextField("Project name", text: $title)
                            .font(.title3.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)

                        Divider().padding(.leading, 16)

                        TextField("Goal or description", text: $notes, axis: .vertical)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(2...6)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // Organize
                    sectionHeader("Organize")
                    VStack(spacing: 0) {
                        HStack {
                            Label("Area", systemImage: "square.grid.2x2")
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            Spacer()
                            Picker("", selection: $selectedAreaID) {
                                Text("No area").tag(UUID?.none)
                                ForEach(areas) { area in
                                    Text(area.title).tag(Optional(area.id))
                                }
                            }
                            .labelsHidden()
                            .tint(.secondary)
                            .lineLimit(1)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // Color
                    sectionHeader("Color")
                    VStack(spacing: 0) {
                        HStack(spacing: 10) {
                            ForEach(tintOptions, id: \.self) { hex in
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        if tintHex == hex {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .onTapGesture { tintHex = hex }
                            }

                            // Custom color picker
                            ColorPicker("", selection: $customColor, supportsOpacity: false)
                                .labelsHidden()
                                .frame(width: 32, height: 32)
                                .onChange(of: customColor) {
                                    tintHex = customColor.toHex()
                                }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { createProject() } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(canSave ? .green : .secondary)
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.leading, 4)
            .padding(.top, 12)
    }

    // MARK: - Actions

    private func createProject() {
        let area = areas.first(where: { $0.id == selectedAreaID })
        let project = Project(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            goalSummary: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            tintHex: tintHex,
            sortOrder: Double(areas.flatMap(\.projectList).count),
            area: area
        )
        modelContext.insert(project)
        try? modelContext.save()
        dismiss()
    }
}
