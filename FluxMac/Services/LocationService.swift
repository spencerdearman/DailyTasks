//
//  LocationService.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import Combine
import CoreLocation
import Foundation
import MapKit

// MARK: - LocationService

/// Manages device location updates and geocoding for location-aware features.
@MainActor
final class LocationService: ObservableObject {

    // MARK: Published State

    @Published private(set) var currentLocation: CLLocationCoordinate2D?
    @Published private(set) var currentCity: String?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    // MARK: Private

    private let manager = CLLocationManager()
    private var delegate: Delegate?

    // MARK: Public Methods

    func start() {
        let d = Delegate { [weak self] location in
            Task { @MainActor [weak self] in
                self?.currentLocation = location.coordinate
                self?.updateCity(from: location.coordinate)
            }
        } onAuthChange: { [weak self] status in
            Task { @MainActor in
                self?.authorizationStatus = status
            }
        }
        delegate = d
        manager.delegate = d
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 500

        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorized {
            manager.startUpdatingLocation()
        }
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedAlways || authorizationStatus == .authorized
    }

    /// Forward geocode: address string → coordinate using MKLocalSearch
    func geocode(_ address: String) async -> CLLocationCoordinate2D? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = address
        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            return response.mapItems.first?.placemark.coordinate
        } catch {
            print("[LocationService] Geocode failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Reverse geocode: coordinate → readable name using MKLocalSearch
    func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async -> String? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = ""
        request.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 100,
            longitudinalMeters: 100
        )
        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            if let item = response.mapItems.first {
                let pm = item.placemark
                let name = [pm.name, pm.locality].compactMap { $0 }.joined(separator: ", ")
                return name.isEmpty ? nil : name
            }
            return nil
        } catch {
            return nil
        }
    }

    /// A summary string for the agent prompt
    var locationSummary: String? {
        guard let city = currentCity else { return nil }
        return "Near \(city)"
    }

    // MARK: Private Methods

    private func updateCity(from coordinate: CLLocationCoordinate2D) {
        Task {
            // Use a point-of-interest search to find nearby location name
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = "city"
            request.region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 5000,
                longitudinalMeters: 5000
            )
            do {
                let search = MKLocalSearch(request: request)
                let response = try await search.start()
                if let pm = response.mapItems.first?.placemark {
                    let city = [pm.locality, pm.administrativeArea].compactMap { $0 }.joined(separator: ", ")
                    if !city.isEmpty {
                        self.currentCity = city
                    }
                }
            } catch {
                // Silently ignore
            }
        }
    }

    // MARK: - CLLocationManager Delegate

    private class Delegate: NSObject, CLLocationManagerDelegate {
        let onLocation: (CLLocation) -> Void
        let onAuthChange: (CLAuthorizationStatus) -> Void

        init(onLocation: @escaping (CLLocation) -> Void, onAuthChange: @escaping (CLAuthorizationStatus) -> Void) {
            self.onLocation = onLocation
            self.onAuthChange = onAuthChange
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let location = locations.last else { return }
            onLocation(location)
        }

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            onAuthChange(manager.authorizationStatus)
            if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorized {
                manager.startUpdatingLocation()
            }
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            print("[LocationService] Location error: \(error.localizedDescription)")
        }
    }
}
