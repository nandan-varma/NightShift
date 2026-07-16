import SwiftUI
import AppKit
import CoreLocation

struct LocationSectionView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var locationService: LocationService

    @State private var citySearchText = ""
    @State private var isResolving = false
    @State private var resolutionError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Location")
                .font(.subheadline)

            Picker("Location Mode", selection: $settings.locationMode) {
                Text("Automatic").tag(LocationMode.automatic)
                Text("Manual").tag(LocationMode.manual)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch settings.locationMode {
            case .automatic:
                automaticSection
            case .manual:
                manualSection
            }
        }
    }

    @ViewBuilder
    private var automaticSection: some View {
        switch locationService.authorizationStatus {
        case .denied, .restricted:
            VStack(alignment: .leading, spacing: 4) {
                Text("Location access needed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .font(.caption)
            }
        default:
            HStack {
                if let coordinate = locationService.currentCoordinate {
                    Text(String(format: "%.2f, %.2f", coordinate.latitude, coordinate.longitude))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Locating…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Refresh") {
                    locationService.requestAuthorizationAndLocation()
                }
                .font(.caption)
            }
        }
    }

    private var manualSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("City or address", text: $citySearchText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(resolveCity)
                Button("Find") { resolveCity() }
                    .disabled(citySearchText.isEmpty || isResolving)
            }

            if !settings.manualLocationName.isEmpty {
                Text(settings.manualLocationName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let resolutionError {
                Text(resolutionError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            DisclosureGroup("Enter coordinates manually") {
                HStack {
                    TextField("Latitude", value: $settings.manualLatitude, format: .number)
                        .textFieldStyle(.roundedBorder)
                    TextField("Longitude", value: $settings.manualLongitude, format: .number)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .font(.caption)
        }
    }

    private func resolveCity() {
        guard !citySearchText.isEmpty else { return }
        isResolving = true
        resolutionError = nil
        Task {
            do {
                let place = try await GeocodingService.resolve(addressString: citySearchText)
                settings.manualLatitude = place.coordinate.latitude
                settings.manualLongitude = place.coordinate.longitude
                settings.manualLocationName = place.displayName
                resolutionError = nil
            } catch {
                resolutionError = "No results found"
            }
            isResolving = false
        }
    }
}
