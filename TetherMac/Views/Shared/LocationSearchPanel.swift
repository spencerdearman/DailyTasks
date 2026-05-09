//
//  LocationSearchPanel.swift
//  TetherMac
//
//  Created by Spencer Dearman.
//

import Combine
import MapKit
import SwiftData
import SwiftUI

// MARK: - LocationSearchPanel

/// A popover panel for searching and assigning a location to a task using MapKit autocomplete.
struct LocationSearchPanel: View {
    @Environment(\.modelContext) private var modelContext
    let task: TaskItem
    @Binding var isPresented: Bool

    @StateObject private var completer = LocationCompleterModel()
    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "location")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("Search location…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .onChange(of: searchText) { _, newValue in
                        completer.search(query: newValue)
                    }
            }
            .padding(8)

            // Current location display
            if let name = task.locationName, !name.isEmpty, searchText.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                    Text(name)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        task.locationName = nil
                        task.locationLatitude = nil
                        task.locationLongitude = nil
                        task.updatedAt = .now
                        try? modelContext.save()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }

            // Search results
            if !completer.results.isEmpty && !searchText.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(completer.results.prefix(6), id: \.self) { result in
                        Button {
                            selectResult(result)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
            }
        }
    }

    private func selectResult(_ result: MKLocalSearchCompletion) {
        let request = MKLocalSearch.Request(completion: result)
        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            guard let item = response?.mapItems.first else {
                // Fallback: save title without coordinates
                Task { @MainActor in
                    task.locationName = result.title
                    task.locationLatitude = nil
                    task.locationLongitude = nil
                    task.updatedAt = .now
                    try? modelContext.save()
                    searchText = ""
                }
                return
            }
            Task { @MainActor in
                task.locationName = item.name ?? result.title
                task.locationLatitude = item.placemark.coordinate.latitude
                task.locationLongitude = item.placemark.coordinate.longitude
                task.updatedAt = .now
                try? modelContext.save()
                searchText = ""
            }
        }
    }
}

// MARK: - LocationCompleterModel

/// An observable wrapper around MKLocalSearchCompleter for autocomplete suggestions.
final class LocationCompleterModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func search(query: String) {
        if query.isEmpty {
            results = []
        } else {
            completer.queryFragment = query
        }
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.results = completer.results
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // Silently clear on error
        DispatchQueue.main.async {
            self.results = []
        }
    }
}
