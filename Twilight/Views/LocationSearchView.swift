import SwiftUI

/// City search + manual lat/long entry, shared between the main dashboard's
/// location section and onboarding.
struct LocationSearchView: View {
    @Bindable var settings: SettingsStore
    var onResolved: (() -> Void)?

    @State private var citySearchText = ""
    @State private var isResolving = false
    @State private var resolutionError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("City or address", text: $citySearchText)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isResolving)
                    .onSubmit(resolveCity)
                Button("Find") { resolveCity() }
                    .disabled(citySearchText.isEmpty || isResolving)
            }

            if !settings.locationName.isEmpty {
                Label(settings.locationName, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let resolutionError {
                Text(resolutionError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            DisclosureGroup("Enter coordinates manually") {
                HStack {
                    TextField("Latitude", value: $settings.latitude, format: .number)
                        .textFieldStyle(.roundedBorder)
                    TextField("Longitude", value: $settings.longitude, format: .number)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .font(.caption)
        }
    }

    private func resolveCity() {
        guard !citySearchText.isEmpty, !isResolving else { return }
        isResolving = true
        resolutionError = nil
        Task {
            do {
                let place = try await GeocodingService.resolve(addressString: citySearchText)
                settings.latitude = place.coordinate.latitude
                settings.longitude = place.coordinate.longitude
                settings.locationName = place.displayName
                resolutionError = nil
                onResolved?()
            } catch {
                resolutionError = "No results found"
            }
            isResolving = false
        }
    }
}
