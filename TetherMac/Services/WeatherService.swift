//
//  WeatherService.swift
//  TetherMac
//
//  Created by Spencer Dearman.
//

import Combine
import CoreLocation
import Foundation
import WeatherKit

// MARK: - TetherWeatherService

/// Fetches current weather and today's forecast using WeatherKit.
/// Provides summaries for the agent prompt and synthesis view.
@MainActor
final class TetherWeatherService: ObservableObject {

    // MARK: Published Properties

    @Published private(set) var currentCondition: String?
    @Published private(set) var currentTemp: String?
    @Published private(set) var todayHigh: String?
    @Published private(set) var todayLow: String?
    @Published private(set) var precipitationChance: Int?
    @Published private(set) var summary: String?
    @Published private(set) var cityName: String?

    // MARK: Private Properties

    private var lastFetchDate: Date?
    private var dailyForecasts: [(date: Date, high: String, low: String, condition: String, precipChance: Int)] = []

    // MARK: Public Methods

    /// Fetches weather for the given location. Caches for 30 minutes.
    func fetch(for location: CLLocation, cityName: String? = nil) async {
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

            // Daily forecasts (store all available days)
            dailyForecasts = weather.dailyForecast.map { day in
                (date: day.date,
                 high: formatTemp(day.highTemperature.value),
                 low: formatTemp(day.lowTemperature.value),
                 condition: day.condition.description,
                 precipChance: Int(day.precipitationChance * 100))
            }

            // Today's forecast
            if let today = weather.dailyForecast.first {
                todayHigh = formatTemp(today.highTemperature.value)
                todayLow = formatTemp(today.lowTemperature.value)
                precipitationChance = Int(today.precipitationChance * 100)
            }

            // Build summary string
            self.cityName = cityName
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

    /// Weather summary for a specific date. Falls back to current-day summary if date is today.
    func summary(for date: Date) -> String? {
        let cal = Calendar.current
        // If it's today, return the normal summary
        if cal.isDateInToday(date) { return summary }

        // Find matching forecast day
        guard let forecast = dailyForecasts.first(where: { cal.isDate($0.date, inSameDayAs: date) }) else {
            return nil
        }

        var parts = ["\(forecast.condition.capitalized)"]
        parts.append("H: \(forecast.high) L: \(forecast.low)")
        if forecast.precipChance > 20 {
            parts.append("\(forecast.precipChance)% rain")
        }
        if let city = cityName {
            parts.append(city)
        }
        return parts.joined(separator: " · ")
    }

    // MARK: Private Methods

    private func buildSummary() {
        guard let condition = currentCondition, let temp = currentTemp else {
            summary = nil
            return
        }

        var parts = ["\(temp), \(condition.capitalized)"]
        if let high = todayHigh, let low = todayLow {
            parts.append("H: \(high) L: \(low)")
        }
        if let precip = precipitationChance, precip > 20 {
            parts.append("\(precip)% rain")
        }
        if let city = cityName {
            parts.append(city)
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
