//
//  ConfettiView.swift
//  Flux Watch App
//
//  Created by Spencer Dearman.
//

import SwiftUI

struct ConfettiParticle: Identifiable {
    let id = UUID()
    var color: Color
    var size: CGFloat
    var endOffsetX: CGFloat
    var endOffsetY: CGFloat
}

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var animate = false
    
    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .offset(x: animate ? particle.endOffsetX : 0, y: animate ? particle.endOffsetY : 0)
                    .scaleEffect(animate ? 0.3 : 1.0)
                    .opacity(animate ? 0 : 1)
            }
        }
        .onAppear {
            let colors: [Color] = [.red, .blue, .green, .yellow, .orange, .purple, .pink]
            for _ in 0..<20 {
                let particle = ConfettiParticle(
                    color: colors.randomElement() ?? .accentColor,
                    size: CGFloat.random(in: 8...16),
                    endOffsetX: CGFloat.random(in: -140...140),
                    endOffsetY: CGFloat.random(in: -140...140)
                )
                particles.append(particle)
            }
            
            withAnimation(.easeOut(duration: 1.5)) {
                animate = true
            }
        }
        .allowsHitTesting(false)
    }
}
