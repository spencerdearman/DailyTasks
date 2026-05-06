import SwiftData
import SwiftUI

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
        NavigationStack {
            Form {
                Section {
                    TextField("Area name", text: $title)
                    TextField("Description", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                }

                Section("Icon") {
                    HStack(spacing: 10) {
                        ForEach(symbolOptions, id: \.self) { symbol in
                            Image(systemName: symbol)
                                .font(.title3)
                                .foregroundStyle(symbolName == symbol ? Color(hex: tintHex) : .secondary)
                                .frame(width: 36, height: 36)
                                .background(
                                    symbolName == symbol
                                    ? Color(hex: tintHex).opacity(0.12)
                                    : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                                .onTapGesture { symbolName = symbol }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Color") {
                    HStack(spacing: 12) {
                        ForEach(tintOptions, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 30, height: 30)
                                .overlay {
                                    if tintHex == hex {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture { tintHex = hex }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("New Area")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createArea() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .fontWeight(.semibold)
                }
            }
        }
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
