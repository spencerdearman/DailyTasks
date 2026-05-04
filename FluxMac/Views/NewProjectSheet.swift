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
        VStack(alignment: .leading, spacing: 18) {
            Text("New Project")
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
                
                Button("Create") {
                    createProject()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
        .background(.ultraThinMaterial)
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
