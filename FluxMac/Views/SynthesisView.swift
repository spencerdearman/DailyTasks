//
//  SynthesisView.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

// MARK: - SynthesisView

/// Displays the AI-generated daily briefing with greeting, conflicts, and a suggested plan.
struct SynthesisView: View {

    // MARK: Properties

    let synthesis: DailySynthesis
    let onDismiss: () -> Void

    @State private var showContent = false

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            headerSection

            Divider()
                .padding(.horizontal, 24)
                .opacity(0.5)

            contentScroll

            footerButton
        }
        .frame(width: 480)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .shadow(color: .black.opacity(0.35), radius: 40, y: 12)
        .scaleEffect(showContent ? 1 : 0.97)
        .opacity(showContent ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                showContent = true
            }
        }
    }

    // MARK: Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(dateLabel)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text("Good Morning")
                    .font(.system(size: 22, weight: .semibold))
            }

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 24, height: 24)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 12)
    }

    // MARK: Content

    private var contentScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !synthesis.greeting.isEmpty {
                    Text(markdownString(synthesis.greeting))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.primary.opacity(0.8))
                        .lineSpacing(3)
                }

                if !synthesis.conflicts.isEmpty {
                    conflictsSection
                }

                if !synthesis.suggestedPlan.isEmpty {
                    suggestedPlanSection
                }

                if synthesis.overdueCount > 0 {
                    overdueIndicator
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(maxHeight: 380)
        .mask(
            VStack(spacing: 0) {
                Color.black
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 4)
            }
        )
    }

    // MARK: Sections

    private var conflictsSection: some View {
        synthesisSection("Heads Up", icon: "exclamationmark.triangle.fill", iconColor: .orange) {
            ForEach(Array(synthesis.conflicts.enumerated()), id: \.offset) { _, conflict in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(Color.orange.opacity(0.6))
                        .frame(width: 5, height: 5)
                        .padding(.top, 6)

                    Text(markdownString(conflict))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.primary.opacity(0.75))
                        .lineSpacing(2)
                }
            }
        }
    }

    private var suggestedPlanSection: some View {
        synthesisSection("Your Day", icon: "calendar.badge.clock", iconColor: .blue) {
            Text(markdownString(synthesis.suggestedPlan))
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.primary.opacity(0.8))
                .lineSpacing(3)
        }
    }

    private var overdueIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 12))
                .foregroundStyle(.red.opacity(0.7))

            Text("**\(synthesis.overdueCount)** overdue task\(synthesis.overdueCount == 1 ? "" : "s") need\(synthesis.overdueCount == 1 ? "s" : "") attention")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: Footer

    private var footerButton: some View {
        Button {
            onDismiss()
        } label: {
            Text("Start Your Day")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .padding(.top, 8)
    }

    // MARK: Private Methods

    private func synthesisSection<Content: View>(
        _ title: String,
        icon: String,
        iconColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(iconColor)

                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: synthesis.date)
    }

    private func markdownString(_ text: String) -> AttributedString {
        if let attributed = try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return attributed
        }
        return AttributedString(text)
    }
}
