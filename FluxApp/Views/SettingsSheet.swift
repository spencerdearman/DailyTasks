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
                            Text("Default view")
                            Spacer()
                            Picker("", selection: $defaultView) {
                                Text("Inbox").tag("inbox")
                                Text("Today").tag("today")
                                Text("Upcoming").tag("upcoming")
                                Text("Open").tag("anytime")
                            }
                            .labelsHidden()
                            .tint(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // Agent section
                    sectionHeader("Agent")
                    VStack(spacing: 0) {
                        SecureField("Gemini API Key", text: $geminiAPIKey)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .onChange(of: geminiAPIKey) {
                                if validationState != .idle {
                                    validationState = .idle
                                }
                            }

                        if !geminiAPIKey.isEmpty {
                            Divider().padding(.leading, 16)

                            HStack {
                                validationStatus

                                Spacer()

                                Button(validationState == .valid ? "Revalidate" : "Validate") {
                                    validateKey()
                                }
                                .font(.subheadline.weight(.medium))
                                .disabled(validationState == .validating)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Text("Get a free key from Google AI Studio. Powers natural language task management.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
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
