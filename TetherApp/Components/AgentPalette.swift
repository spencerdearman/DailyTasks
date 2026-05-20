//
//  AgentPalette.swift
//  TetherApp
//
//  Created by Spencer Dearman.
//

import SwiftUI

// MARK: - Agent Color Palette

/// Unified blue-purple color palette for all agent-related UI.
enum AgentPalette {
    static let deep = Color(red: 0.18, green: 0.12, blue: 0.45)       // midnight indigo
    static let mid = Color(red: 0.30, green: 0.22, blue: 0.65)        // rich violet
    static let lavender = Color(red: 0.45, green: 0.35, blue: 0.80)   // soft lavender
    static let bright = Color(red: 0.55, green: 0.42, blue: 0.92)     // vivid purple
    static let periwinkle = Color(red: 0.48, green: 0.52, blue: 0.95) // periwinkle blue
    static let accent = Color(red: 0.38, green: 0.58, blue: 1.0)      // cornflower blue
    static let sky = Color(red: 0.42, green: 0.72, blue: 1.0)         // sky blue
    static let glow = Color(red: 0.50, green: 0.45, blue: 0.95)       // violet glow

    static let gradient = LinearGradient(
        colors: [mid, lavender, bright],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let wideGradient = LinearGradient(
        colors: [mid, lavender, bright, periwinkle, accent],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let borderGradient = LinearGradient(
        colors: [mid.opacity(0.35), bright.opacity(0.25), periwinkle.opacity(0.2), accent.opacity(0.3)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
