//
//  SettingsSheet.swift
//  TetherApp
//
//  Created by Spencer Dearman.
//

import SwiftUI
import SwiftData

// MARK: - SettingsSheet

/// The application settings screen with preferences and API key configuration.
struct SettingsSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var calendarStore: CalendarStore
    @AppStorage("tetherShowCompletedTasks") private var showCompleted = false
    @AppStorage("tetherShowTaskCounts") private var showTaskCounts = true
    @AppStorage("tetherAppleCalendarEnabled") private var appleCalendarEnabled = true
    @AppStorage("tetherGoogleCalendarEnabled") private var googleCalendarEnabled = true

    @AppStorage("geminiAPIKey") private var geminiAPIKey = ""

    @State private var validationState: ValidationState = .idle
    @State private var showResetConfirm = false

    private enum ValidationState: Equatable {
        case idle
        case validating
        case valid
        case invalid(String)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    // General section
                    sectionHeader("General")
                    VStack(spacing: 0) {
                        HStack {
                            Text("Show completed tasks")
                            Spacer()
                            Toggle("", isOn: $showCompleted)
                                .labelsHidden()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        Divider().padding(.leading, 16)

                        HStack {
                            Text("Show task counts")
                            Spacer()
                            Toggle("", isOn: $showTaskCounts)
                                .labelsHidden()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)


                    }
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // Calendars section
                    sectionHeader("Calendars")
                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: "apple.logo")
                            Text("Apple Calendar")
                            Spacer()
                            Toggle("", isOn: $appleCalendarEnabled)
                                .labelsHidden()
                                .onChange(of: appleCalendarEnabled) { calendarStore.refresh() }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        Divider().padding(.leading, 16)

                        HStack {
                            Image(systemName: "g.circle.fill")
                            Text("Google Calendar")
                            Spacer()
                            Toggle("", isOn: $googleCalendarEnabled)
                                .labelsHidden()
                                .onChange(of: googleCalendarEnabled) { calendarStore.refresh() }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        if googleCalendarEnabled {
                            Divider().padding(.leading, 16)

                            HStack {
                                if calendarStore.googleSignedIn {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text(calendarStore.googleUserEmail ?? "Connected")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    Spacer()
                                    Button("Sign Out") {
                                        calendarStore.signOutGoogle()
                                    }
                                    .font(.subheadline.weight(.medium))
                                } else {
                                    Text("Not connected")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Button("Connect") {
                                        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                              let rootVC = scene.windows.first?.rootViewController else { return }
                                        Task {
                                            try? await calendarStore.signInGoogle(presenting: rootVC)
                                        }
                                    }
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 5)
                                    .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // Tether Agent section
                    Label("Tether Agent", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                        .padding(.top, 12)

                    VStack(spacing: 0) {
                        HStack {
                            Text("Gemini API Key")
                            Spacer()
                            SecureField("Paste key here", text: $geminiAPIKey)
                                .textContentType(.password)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 200)
                                .onChange(of: geminiAPIKey) {
                                    if validationState != .idle {
                                        validationState = .idle
                                    }
                                }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        if !geminiAPIKey.isEmpty {
                            Divider().padding(.leading, 16)

                            HStack {
                                validationStatus

                                Spacer()

                                Button {
                                    validateKey()
                                } label: {
                                    Text(validationState == .valid ? "Revalidate" : "Validate")
                                        .font(.subheadline.weight(.medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 5)
                                        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .disabled(validationState == .validating)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Text("Get a free key from Google AI Studio. Powers natural language task management.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 4)

                    // Data section
                    sectionHeader("Data")
                    VStack(spacing: 0) {
                        Button(role: .destructive) {
                            showResetConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 16, weight: .medium))
                                Text("Reset & Load Sample Data")
                                Spacer()
                            }
                            .foregroundStyle(.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Text("Deletes all tasks, projects, and areas, then loads demo content.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Settings")
            .tint(Color(.systemGray))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
            }
            .confirmationDialog("Reset all data?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("Reset & Load Sample Data", role: .destructive) {
                    resetAndReseed()
                }
            } message: {
                Text("This will permanently delete all your tasks, projects, and areas, then load sample data.")
            }
        }
    }

    // MARK: - Reset & Reseed

    private func resetAndReseed() {
        // Delete all data in dependency order
        let tasks = (try? modelContext.fetch(FetchDescriptor<TaskItem>())) ?? []
        let assignments = (try? modelContext.fetch(FetchDescriptor<TaskTagAssignment>())) ?? []
        let checklists = (try? modelContext.fetch(FetchDescriptor<ChecklistItem>())) ?? []
        let headings = (try? modelContext.fetch(FetchDescriptor<Heading>())) ?? []
        let projects = (try? modelContext.fetch(FetchDescriptor<Project>())) ?? []
        let areas = (try? modelContext.fetch(FetchDescriptor<Area>())) ?? []
        let tags = (try? modelContext.fetch(FetchDescriptor<Tag>())) ?? []

        for item in checklists { modelContext.delete(item) }
        for item in assignments { modelContext.delete(item) }
        for item in tasks { modelContext.delete(item) }
        for item in headings { modelContext.delete(item) }
        for item in projects { modelContext.delete(item) }
        for item in areas { modelContext.delete(item) }
        for item in tags { modelContext.delete(item) }
        try? modelContext.save()

        // Reseed
        SampleDataSeeder.bootstrapIfNeeded(in: modelContext)
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

    // MARK: - Validation Status

    @ViewBuilder
    private var validationStatus: some View {
        switch validationState {
        case .idle:
            EmptyView()
        case .validating:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Validating...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        case .valid:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Key is valid")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
        case .invalid(let reason):
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text(reason)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Validation

    private func validateKey() {
        validationState = .validating
        let key = geminiAPIKey

        Task {
            do {
                let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(key)")!

                let body: [String: Any] = [
                    "contents": [["parts": [["text": "Hi"]]]],
                ]
                let jsonData = try JSONSerialization.data(withJSONObject: body)

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = jsonData
                request.timeoutInterval = 10

                let (_, response) = try await URLSession.shared.data(for: request)

                guard let http = response as? HTTPURLResponse else {
                    validationState = .invalid("No response")
                    return
                }

                if http.statusCode == 200 {
                    validationState = .valid
                } else if http.statusCode == 400 {
                    validationState = .invalid("Invalid API key")
                } else if http.statusCode == 403 {
                    validationState = .invalid("Key not authorized")
                } else {
                    validationState = .invalid("Error (\(http.statusCode))")
                }
            } catch {
                validationState = .invalid("Connection failed")
            }
        }
    }
}
