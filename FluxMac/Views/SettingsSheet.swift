import SwiftData
import SwiftUI

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("fluxShowCompletedTasks") private var showCompleted = false
    @AppStorage("fluxDefaultView") private var defaultView = "inbox"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Settings")
                .font(.system(size: 24, weight: .bold))
            
            VStack(spacing: 0) {
                HStack {
                    Text("Show completed tasks")
                        .font(.body)
                    Spacer()
                    Toggle("", isOn: $showCompleted)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider()
                    .padding(.leading, 16)
                
                HStack {
                    Text("Default view")
                        .font(.body)
                    Spacer()
                    Picker("", selection: $defaultView) {
                        Text("Inbox").tag("inbox")
                        Text("Today").tag("today")
                        Text("Upcoming").tag("upcoming")
                        Text("Open").tag("anytime")
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            
            Spacer()
            
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.body.weight(.medium))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 400, height: 280)
    }
}
