import SwiftUI
import MapKit

nonisolated struct LinkedPlace: Codable, Hashable, Sendable {
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double

    @MainActor init(_ item: MKMapItem) {
        name = item.name ?? "Place"
        address = item.address?.fullAddress ?? ""
        latitude = item.location.coordinate.latitude
        longitude = item.location.coordinate.longitude
    }

    @MainActor var mapItem: MKMapItem {
        let item = MKMapItem(location: CLLocation(latitude: latitude, longitude: longitude), address: nil)
        item.name = name
        return item
    }
}

struct PlaceLinkPicker: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query: String
    @State private var results: [MKMapItem] = []
    @State private var isSearching = false
    @State private var message: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var currentSearch: MKLocalSearch?
    let onSelect: (LinkedPlace) -> Void

    init(name: String, onSelect: @escaping (LinkedPlace) -> Void) {
        _query = State(initialValue: name)
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            List {
                if isSearching { ProgressView("Searching Maps…") }
                if let message { Text(message).foregroundStyle(.secondary) }
                ForEach(Array(results.enumerated()), id: \.offset) { _, item in
                    Button {
                        onSelect(LinkedPlace(item))
                        dismiss()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name ?? "Place").foregroundStyle(.primary)
                                Text(item.address?.fullAddress ?? "")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: { Image(systemName: "mappin.circle.fill") }
                    }
                }
            }
            .upgradeScrollEdgeEffect()
            .navigationTitle("Link a Place")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: "Place or address")
            .onSubmit(of: .search) { startSearch() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { Button("Search") { startSearch() }.disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
            .onAppear { startSearch() }
            .onDisappear { searchTask?.cancel(); currentSearch?.cancel() }
        }
    }

    private func startSearch() {
        searchTask?.cancel()
        currentSearch?.cancel()
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        results = []
        message = nil
        isSearching = true
        searchTask = Task {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = text
            let search = MKLocalSearch(request: request)
            currentSearch = search
            do {
                let response = try await search.start()
                guard !Task.isCancelled else { return }
                results = response.mapItems
                if results.isEmpty { message = "No places found. Try a city or a more specific address." }
            } catch {
                guard !Task.isCancelled else { return }
                message = "Maps couldn’t complete this search. Please try again."
            }
            isSearching = false
        }
    }
}
