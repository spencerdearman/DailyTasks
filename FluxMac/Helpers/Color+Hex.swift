//
//  Color+Hex.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import SwiftUI

extension Color {

    /// Initializes a Color from a hex string (e.g., "#FF5733" or "FF5733").
    init(hex: String) {
        let sanitized = hex.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)

        let red = Double((value & 0xFF0000) >> 16) / 255
        let green = Double((value & 0x00FF00) >> 8) / 255
        let blue = Double(value & 0x0000FF) / 255

        self.init(red: red, green: green, blue: blue)
    }
}
