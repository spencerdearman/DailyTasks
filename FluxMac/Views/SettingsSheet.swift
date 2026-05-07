//
//  SettingsSheet.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import SwiftUI

// MARK: - SettingsSheet

/// The application settings panel with preferences and API key configuration.
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

            // Flux Agent section
            VStack(alignment: .leading, spacing: 8) {
                Label("Flux Agent", systemImage: "sparkles")
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
        .padding(28)
        .frame(width: 460, height: 440)
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
