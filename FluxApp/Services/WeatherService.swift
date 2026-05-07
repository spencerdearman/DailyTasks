//
//  WeatherService.swift
//  FluxApp
//
//  Created by Spencer Dearman.
//

import Combine
import CoreLocation
import Foundation
import WeatherKit

// MARK: - FluxWeatherService

/// Fetches current weather and today's forecast using WeatherKit.
@MainActor
final class FluxWeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {

    // MARK: Published Properties

    @Published private(set) var currentCondition: String?
    @Published private(set) var currentTemp: String?
    @Published private(set) var todayHigh: String?
    @Published private(set) var todayLow: String?
    @Published private(set) var precipitationChance: Int?
    @Published private(set) var summary: String?
    @Published private(set) var lastLocation: CLLocation?

    // MARK: Private Properties

    private let locationManager = CLLocationManager()
    private var lastFetchDate: Date?
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    // MARK: Init

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    // MARK: Public Methods

    /// Requests location permission and fetches weather.
    func fetchWeather() async {
        let location = await requestLocation()
        guard let location else { return }
        lastLocation = location
        await fetch(for: location)
    }

    /// Fetches weather for the given location. Caches for 30 minutes.
    func fetch(for location: CLLocation) async {
        if let last = lastFetchDate, Date().timeIntervalSince(last) < 1800 {
            return
        }

        do {
            let service = WeatherKit.WeatherService.shared
            let weather = try await service.weather(for: location)

            let current = weather.currentWeather
            currentCondition = current.condition.description
            currentTemp = formatTemp(current.temperature.value)

            if let today = weather.dailyForecast.first {
                todayHigh = formatTemp(today.highTemperature.value)
                todayLow = formatTemp(today.lowTemperature.value)
                precipitationChance = Int(today.precipitationChance * 100)
            }

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

    // MARK: Location

    private func requestLocation() async -> CLLocation? {
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            // Wait briefly for authorization
            try? await Task.sleep(for: .milliseconds(500))
        }

        guard locationManager.authorizationStatus == .authorizedWhenInUse ||
              locationManager.authorizationStatus == .authorizedAlways else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            locationContinuation = continuation
            locationManager.requestLocation()
        }
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            locationContinuation?.resume(returning: locations.first)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[Weather] Location error: \(error)")
        Task { @MainActor in
            locationContinuation?.resume(returning: nil)
            locationContinuation = nil
        }
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
