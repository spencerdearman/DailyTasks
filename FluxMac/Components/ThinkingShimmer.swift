//
//  ThinkingShimmer.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import SwiftUI

/// An animated "Thinking..." label with a shimmer gradient that sweeps across the text.
struct ThinkingShimmer: View {
    @State private var animating = false

    var body: some View {
        Text("Thinking...")
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
                    Text("Thinking...")
                        .font(.system(size: 13, weight: .medium))
                }
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
}
