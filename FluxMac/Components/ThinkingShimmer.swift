//
//  ThinkingShimmer.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import SwiftUI

/// An animated thinking label with a shimmer gradient and rotating status messages.
struct ThinkingShimmer: View {
    var contextHint: String?

    @State private var animating = false
    @State private var messageIndex = 0

    private var messages: [String] {
        if let hint = contextHint, !hint.isEmpty {
            return [hint]
        }
        return [
            "Thinking...",
            "Looking at your tasks...",
            "Checking your calendar...",
            "Putting it together...",
        ]
    }

    private var currentMessage: String {
        messages[messageIndex % messages.count]
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 2.5)) { timeline in
            let _ = updateMessage(timeline.date)
            shimmerText(currentMessage)
        }
        .onAppear {
            withAnimation(
                .linear(duration: 1.5)
                .repeatForever(autoreverses: false)
            ) {
                animating = true
            }
        }
    }

    private func shimmerText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.primary.opacity(0.15))
            .overlay {
                GeometryReader { geo in
                    let width = geo.size.width
                    LinearGradient(
                        colors: [
                            .clear,
                            Color.primary.opacity(0.35),
                            .clear,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: width * 0.6)
                    .offset(x: animating ? width : -width * 0.6)
                }
                .mask {
                    Text(text)
                        .font(.system(size: 13, weight: .medium))
                }
            }
            .animation(.easeInOut(duration: 0.4), value: text)
            .contentTransition(.interpolate)
    }

    private func updateMessage(_ date: Date) {
        let newIndex = Int(date.timeIntervalSinceReferenceDate / 2.5) % messages.count
        if newIndex != messageIndex {
            messageIndex = newIndex
        }
    }
}
