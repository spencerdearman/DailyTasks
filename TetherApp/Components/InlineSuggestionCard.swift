//
//  InlineSuggestionCard.swift
//  TetherApp
//
//  Created by Spencer Dearman.
//

import SwiftUI

// MARK: - InlineSuggestionCard

/// Displays a contextual agent suggestion inline on task list screens.
/// Shows a message with Accept and Dismiss actions, with gradient border and shimmer effects.
struct InlineSuggestionCard: View {

    let suggestion: AgentSuggestion
    let isProcessing: Bool
    let onAccept: () -> Void
    let onDismiss: () -> Void

    @State private var appeared = false
    @State private var shimmerAnimating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let phase = sin(t * 0.5) * 0.5 + 0.5

                    TetherIcon(size: 20)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AgentPalette.mid, AgentPalette.bright, AgentPalette.accent],
                                startPoint: UnitPoint(x: CGFloat(phase) * 0.8, y: 0),
                                endPoint: UnitPoint(x: 0.5 + CGFloat(phase) * 0.5, y: 1)
                            )
                        )
                        .symbolEffect(.pulse, isActive: isProcessing)
                }

                if isProcessing {
                    processingShimmer
                } else {
                    Text(suggestion.message)
                        .font(.subheadline)
                        .foregroundStyle(.primary.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Button(action: onAccept) {
                    HStack(spacing: 5) {
                        if isProcessing {
                            TetherIcon(size: 14)
                        }
                        Text(isProcessing ? "Working..." : suggestion.actionLabel)
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background {
                        Capsule().fill(isProcessing ? AgentPalette.mid : AgentPalette.mid.opacity(0.7))
                    }
                    .overlay {
                        if isProcessing {
                            GeometryReader { geo in
                                let w = geo.size.width
                                LinearGradient(
                                    colors: [
                                        .clear,
                                        AgentPalette.lavender.opacity(0.5),
                                        AgentPalette.accent.opacity(0.6),
                                        AgentPalette.sky.opacity(0.5),
                                        AgentPalette.accent.opacity(0.6),
                                        AgentPalette.lavender.opacity(0.5),
                                        .clear,
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: w * 1.2)
                                .offset(x: shimmerAnimating ? w * 0.8 : -w * 1.2)
                            }
                            .clipShape(Capsule())
                            .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: isProcessing)
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)

                if !isProcessing {
                    Button(action: onDismiss) {
                        Text("Dismiss")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }

                Spacer()
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AgentPalette.borderGradient, lineWidth: 0.5)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                appeared = true
            }
        }
        .onChange(of: isProcessing) { _, working in
            if working {
                shimmerAnimating = false
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        shimmerAnimating = true
                    }
                }
            }
        }
    }

    /// Shimmer text that matches the ThinkingShimmer style.
    private var processingShimmer: some View {
        Text(suggestion.message)
            .font(.subheadline)
            .foregroundStyle(.primary.opacity(0.12))
            .overlay {
                GeometryReader { geo in
                    let w = geo.size.width
                    LinearGradient(
                        colors: [
                            .clear,
                            AgentPalette.glow.opacity(0.4),
                            Color.primary.opacity(0.3),
                            AgentPalette.glow.opacity(0.4),
                            .clear,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: w * 0.5)
                    .offset(x: shimmerAnimating ? w : -w * 0.5)
                }
                .mask {
                    Text(suggestion.message)
                        .font(.subheadline)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
    }
}
