//
//  NewAreaSheet.swift
//  FluxApp
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

// MARK: - NewAreaSheet

/// A sheet for creating a new area with an icon, color, and optional description.
struct NewAreaSheet: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // MARK: - Queries

    @Query(sort: \Area.sortOrder) private var areas: [Area]

    // MARK: - State

    @State private var title = ""
    @State private var notes = ""
    @State private var symbolName = "square.grid.2x2"
    @State private var tintHex = "#3B82F6"
    @State private var customColor = Color.blue
    @State private var showEmojiField = false
    @State private var customEmoji = ""

    // MARK: - Constants

    private let symbolOptions = [
        "square.grid.2x2", "briefcase.fill", "heart.fill",
        "house.fill", "graduationcap.fill", "figure.run",
        "dollarsign.circle.fill", "paintbrush.fill",
        "book.fill", "airplane", "leaf.fill", "gamecontroller.fill",
    ]

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
                        TextField("Area name", text: $title)
                            .font(.title3.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)

                        Divider().padding(.leading, 16)

                        TextField("Description", text: $notes, axis: .vertical)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(2...6)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // Icon
                    sectionHeader("Icon")
                    VStack(spacing: 0) {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                            ForEach(symbolOptions, id: \.self) { symbol in
                                Image(systemName: symbol)
                                    .font(.title3)
                                    .foregroundStyle(symbolName == symbol ? Color(hex: tintHex) : .secondary)
                                    .frame(width: 40, height: 40)
                                    .background(
                                        symbolName == symbol
                                        ? Color(hex: tintHex).opacity(0.15)
                                        : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    )
                                    .onTapGesture {
                                        symbolName = symbol
                                        showEmojiField = false
                                        customEmoji = ""
                                    }
                            }

                            // Custom emoji button
                            Group {
                                if showEmojiField {
                                    TextField("", text: $customEmoji)
                                        .font(.title3)
                                        .multilineTextAlignment(.center)
                                        .frame(width: 40, height: 40)
                                        .background(
                                            Color(hex: tintHex).opacity(0.15),
                                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        )
                                        .onChange(of: customEmoji) {
                                            if customEmoji.count > 1 {
                                                customEmoji = String(customEmoji.suffix(1))
                                            }
                                        }
                                } else {
                                    Image(systemName: "plus")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 40, height: 40)
                                        .background(
                                            Color(.tertiarySystemGroupedBackground),
                                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        )
                                        .onTapGesture {
                                            showEmojiField = true
                                            symbolName = ""
                                        }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
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
            .navigationTitle("New Area")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { createArea() } label: {
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

    private func createArea() {
        let area = Area(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            symbolName: symbolName,
            tintHex: tintHex,
            sortOrder: Double(areas.count)
        )
        modelContext.insert(area)
        try? modelContext.save()
        dismiss()
    }
}
