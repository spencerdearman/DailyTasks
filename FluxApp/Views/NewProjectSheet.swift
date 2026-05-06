import SwiftData
import SwiftUI

struct NewProjectSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Area.sortOrder) private var areas: [Area]

    @State private var title = ""
    @State private var notes = ""
    @State private var selectedAreaID: UUID?
    @State private var tintHex = "#2E6BC6"

    private let tintOptions = ["#2E6BC6", "#62666D", "#6D7563", "#8A7D6A", "#7A7068", "#5B83B7"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Project name", text: $title)
                    TextField("Goal or description", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                }

                Section {
                    Picker("Area", selection: $selectedAreaID) {
                        Text("No area").tag(UUID?.none)
                        ForEach(areas) { area in
                            Text(area.title).tag(Optional(area.id))
                        }
                    }
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
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { createProject() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .fontWeight(.semibold)
                }
            }
        }
    }

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
