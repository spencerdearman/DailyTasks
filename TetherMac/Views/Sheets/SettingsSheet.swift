//
//  SettingsSheet.swift
//  TetherMac
//
//  Created by Spencer Dearman.
//

import SwiftUI
import SwiftData

// MARK: - SettingsSheet

/// The application settings panel with preferences and API key configuration.
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
        VStack(alignment: .leading, spacing: 0) {
            Text("Settings")
                .font(.system(size: 24, weight: .bold))
                .padding(.bottom, 24)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

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
                    Text("Show task counts")
                        .font(.body)
                    Spacer()
                    Toggle("", isOn: $showTaskCounts)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)


            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            // Calendars section
            VStack(alignment: .leading, spacing: 8) {
                Label("Calendars", systemImage: "calendar")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "apple.logo")
                            .font(.body)
                        Text("Apple Calendar")
                            .font(.body)
                        Spacer()
                        Toggle("", isOn: $appleCalendarEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .onChange(of: appleCalendarEnabled) { calendarStore.refresh() }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Divider()
                        .padding(.leading, 16)

                    HStack {
                        Image(systemName: "g.circle.fill")
                            .font(.body)
                        Text("Google Calendar")
                            .font(.body)
                        Spacer()
                        Toggle("", isOn: $googleCalendarEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .onChange(of: googleCalendarEnabled) { calendarStore.refresh() }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if googleCalendarEnabled {
                        Divider()
                            .padding(.leading, 16)

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
                                .buttonStyle(.plain)
                            } else {
                                Text("Not connected")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("Connect") {
                                    guard let window = NSApplication.shared.keyWindow else { return }
                                    Task {
                                        try? await calendarStore.signInGoogle(presenting: window)
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
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            // Tether Agent section
            VStack(alignment: .leading, spacing: 8) {
                Label("Tether Agent", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                VStack(spacing: 0) {
                    HStack {
                        Text("Gemini API Key")
                            .font(.body)
                        Spacer()
                        SecureField("Paste key here", text: $geminiAPIKey)
                            .textFieldStyle(.plain)
                            .frame(maxWidth: 180)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: geminiAPIKey) {
                                // Reset validation when key changes
                                if validationState != .idle {
                                    validationState = .idle
                                }
                            }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if !geminiAPIKey.isEmpty {
                        Divider()
                            .padding(.leading, 16)

                        HStack {
                            // Validation status
                            switch validationState {
                            case .idle:
                                EmptyView()
                            case .validating:
                                ProgressView()
                                    .controlSize(.small)
                                Text("Validating...")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            case .valid:
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("Key is valid")
                                    .font(.subheadline)
                                    .foregroundStyle(.green)
                            case .invalid(let reason):
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                                Text(reason)
                                    .font(.subheadline)
                                    .foregroundStyle(.red)
                                    .lineLimit(1)
                            }

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
                        .animation(.easeOut(duration: 0.2), value: validationState)
                    }
                }
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text("Get a free key from Google AI Studio. Powers natural language task management via ⌘A.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }

            // Data section
            VStack(alignment: .leading, spacing: 8) {
                Label("Data", systemImage: "cylinder.split.1x2")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                VStack(spacing: 0) {
                    Button {
                        showResetConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.body)
                            Text("Reset & Load Sample Data")
                                .font(.body)
                            Spacer()
                        }
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text("Deletes all tasks, projects, and areas, then loads demo content.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }

            }
            }

            Spacer(minLength: 16)

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
        .padding(28)
        .frame(width: 460, height: 560)
        .alert("Reset all data?", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset & Load Sample Data", role: .destructive) {
                resetAndReseed()
            }
        } message: {
            Text("This will permanently delete all your tasks, projects, and areas, then load sample data.")
        }
    }

    // MARK: - Reset & Reseed

    private func resetAndReseed() {
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

        SampleDataSeeder.bootstrapIfNeeded(in: modelContext)
    }

    // MARK: - Validation

    private func validateKey() {
        validationState = .validating
        let key = geminiAPIKey

        Task {
            do {
                let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(key)")!

                let body: [String: Any] = [
                    "contents": [["parts": [["text": "Hi"]]]]
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
