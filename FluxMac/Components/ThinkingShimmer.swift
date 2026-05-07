//
//  ThinkingShimmer.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import SwiftUI

/// An animated "Thinking..." label with a shimmer highlight that sweeps across the text.
struct ThinkingShimmer: View {
    @State private var animating = false

    var body: some View {
        Text("Thinking...")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.primary.opacity(0.18))
            .mask {
                ZStack {
                    // Base layer — always visible
                    Color.white.opacity(0.4)

                    // Shimmer highlight
                    LinearGradient(
                        colors: [.clear, .white, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 40)
                    .offset(x: animating ? 60 : -60)
                }
            }
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.6)
                    .repeatForever(autoreverses: false)
                ) {
                    animating = true
                }
            }
    }
}
