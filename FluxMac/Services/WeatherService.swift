//
//  WeatherService.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import Combine
import CoreLocation
import Foundation
import WeatherKit

// MARK: - FluxWeatherService

/// Fetches current weather and today's forecast using WeatherKit.
/// Provides summaries for the agent prompt and synthesis view.
@MainActor
final class FluxWeatherService: ObservableObject {

    // MARK: Published Properties

    @Published private(set) var currentCondition: String?
    @Published private(set) var currentTemp: String?
    @Published private(set) var todayHigh: String?
    @Published private(set) var todayLow: String?
    @Published private(set) var precipitationChance: Int?
    @Published private(set) var summary: String?

    // MARK: Private Properties

    private var lastFetchDate: Date?

    // MARK: Public Methods

    /// Fetches weather for the given location. Caches for 30 minutes.
    func fetch(for location: CLLocation) async {
        // Don't refetch within 30 minutes
        if let last = lastFetchDate, Date().timeIntervalSince(last) < 1800 {
            return
        }

        do {
            let service = WeatherKit.WeatherService.shared
            let weather = try await service.weather(for: location)

            // Current conditions
            let current = weather.currentWeather
            currentCondition = current.condition.description
            currentTemp = formatTemp(current.temperature.value)

            // Today's forecast
            if let today = weather.dailyForecast.first {
                todayHigh = formatTemp(today.highTemperature.value)
                todayLow = formatTemp(today.lowTemperature.value)
                precipitationChance = Int(today.precipitationChance * 100)
            }

            // Build summary string
            buildSummary()
            lastFetchDate = Date()

            print("[Weather] Fetched: \(summary ?? "nil")")
        } catch {
            print("[Weather] Failed to fetch: \(error)")
        }
    }

    /// A concise weather summary for AI prompts.
    var promptSummary: String? {
        guard let condition = currentCondition, let temp = currentTemp else { return nil }
        var result = "\(condition), \(temp)"
        if let high = todayHigh, let low = todayLow {
            result += " (high \(high), low \(low))"
        }
        if let precip = precipitationChance, precip > 20 {
            result += ", \(precip)% chance of rain"
        }
        return result
    }

    // MARK: Private Methods

    private func buildSummary() {
        guard let condition = currentCondition, let temp = currentTemp else {
            summary = nil
            return
        }

        var parts = ["\(temp), \(condition.lowercased())"]
        if let high = todayHigh, let low = todayLow {
            parts.append("H: \(high) L: \(low)")
        }
        if let precip = precipitationChance, precip > 20 {
            parts.append("\(precip)% rain")
        }
        summary = parts.joined(separator: " · ")
    }

    private func formatTemp(_ celsius: Double) -> String {
        let formatter = MeasurementFormatter()
        formatter.numberFormatter.maximumFractionDigits = 0
        let measurement = Measurement(value: celsius, unit: UnitTemperature.celsius)
        return formatter.string(from: measurement)
    }
}
