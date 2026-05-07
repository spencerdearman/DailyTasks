//
//  SettingsSheet.swift
//  FluxApp
//
//  Created by Spencer Dearman.
//

import SwiftUI

// MARK: - SettingsSheet

/// The application settings screen with preferences and API key configuration.
struct SettingsSheet: View {

    @Environment(\.dismiss) private var dismiss
    @AppStorage("fluxShowCompletedTasks") private var showCompleted = false
    @AppStorage("fluxDefaultView") private var defaultView = "inbox"
    @AppStorage("geminiAPIKey") private var geminiAPIKey = ""

    @State private var validationState: ValidationState = .idle

    private enum ValidationState: Equatable {
        case idle
        case validating
        case valid
        case invalid(String)
    }

    var body: some View {
        NavigationStack {
            List {
                // General
                Section {
                    Toggle("Show completed tasks", isOn: $showCompleted)

                    Picker("Default view", selection: $defaultView) {
                        Text("Inbox").tag("inbox")
                        Text("Today").tag("today")
                        Text("Upcoming").tag("upcoming")
                        Text("Open").tag("anytime")
                    }
                }

                // Flux Agent
                Section {
                    SecureField("Gemini API Key", text: $geminiAPIKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: geminiAPIKey) {
                            if validationState != .idle {
                                validationState = .idle
                            }
                        }

                    if !geminiAPIKey.isEmpty {
                        HStack {
                            validationStatus

                            Spacer()

                            Button(validationState == .valid ? "Revalidate" : "Validate") {
                                validateKey()
                            }
                            .font(.subheadline.weight(.medium))
                            .disabled(validationState == .validating)
                        }
                    }
                } header: {
                    Label("Agent", systemImage: "sparkles")
                } footer: {
                    Text("Get a free key from Google AI Studio. Powers natural language task management.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
            }
        }
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
