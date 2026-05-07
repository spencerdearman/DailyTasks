//
//  NewAreaSheet.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

// MARK: - NewAreaSheet

/// A modal form for creating a new area with icon and color selection.
struct NewAreaSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \Area.sortOrder) private var areas: [Area]
    
    @State private var title = ""
    @State private var notes = ""
    @State private var symbolName = "square.grid.2x2"
    @State private var tintHex = "#5B83B7"
    
    private let symbolOptions = [
        "square.grid.2x2", "briefcase.fill", "heart.fill",
        "house.fill", "graduationcap.fill", "figure.run",
        "dollarsign.circle.fill", "paintbrush.fill"
    ]
    private let tintOptions = ["#5B83B7", "#62666D", "#6D7563", "#8A7D6A", "#7A7068", "#2E6BC6"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("New Area")
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
                
                Button("Create") {
                    createArea()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(.ultraThinMaterial)
    }
    
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
