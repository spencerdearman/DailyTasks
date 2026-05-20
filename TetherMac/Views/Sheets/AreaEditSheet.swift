//
//  AreaEditSheet.swift
//  TetherMac
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

// MARK: - AreaEditSheet

/// A modal form for editing an existing area's properties.
struct AreaEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var area: Area

    @State private var title: String
    @State private var notes: String
    @State private var symbolName: String
    @State private var tintHex: String

    private let symbolOptions = [
        "square.grid.2x2", "briefcase.fill", "heart.fill",
        "house.fill", "graduationcap.fill", "figure.run",
        "dollarsign.circle.fill", "paintbrush.fill"
    ]
    private let tintOptions = [
        "#E74C3C", "#E67E22", "#F1C40F", "#2ECC71", "#3498DB", "#6C5CE7", "#9B59B6",
        "#5B83B7", "#62666D", "#8E8E93", "#7A7068"
    ]

    init(area: Area) {
        self.area = area
        _title = State(initialValue: area.title)
        _notes = State(initialValue: area.notes)
        _symbolName = State(initialValue: area.symbolName)
        _tintHex = State(initialValue: area.tintHex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Edit Area")
                .font(.title2.weight(.semibold))

            TextField("Area name", text: $title)
                .textFieldStyle(.roundedBorder)
                .font(.title3)

            TextField("Description (optional)", text: $notes)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                Text("Icon")
                    .font(.subheadline.weight(.medium))
                ForEach(symbolOptions, id: \.self) { symbol in
                    Image(systemName: symbol)
                        .font(.title3)
                        .foregroundStyle(symbolName == symbol ? Color(hex: tintHex) : .secondary)
                        .frame(width: 32, height: 32)
                        .background(
                            symbolName == symbol
                            ? Color(hex: tintHex).opacity(0.12)
                            : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .onTapGesture { symbolName = symbol }
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
                    saveArea()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(.ultraThinMaterial)
    }

    private func saveArea() {
        area.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        area.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        area.symbolName = symbolName
        area.tintHex = tintHex
        try? modelContext.save()
        dismiss()
    }
}
