import CoreLocation

/// Wraps CLGeocoder for manual location entry (typed city/address).
/// This is the one place the app briefly touches the network; once a
/// coordinate is resolved it is persisted and the app runs fully offline.
enum GeocodingService {
    struct ResolvedPlace {
        let coordinate: Coordinate
        let displayName: String
    }

    enum GeocodingError: Error {
        case noResults
    }

    static func resolve(addressString: String) async throws -> ResolvedPlace {
        // CLGeocoder is deprecated in favor of MapKit's MKGeocodingRequest as of macOS 26,
        // but that API requires macOS 26+; CLGeocoder is kept deliberately for the 14.0 deployment target.
        let placemarks = try await CLGeocoder().geocodeAddressString(addressString)
        guard let placemark = placemarks.first, let location = placemark.location else {
            throw GeocodingError.noResults
        }

        let displayName = [placemark.locality, placemark.administrativeArea, placemark.country]
            .compactMap { $0 }
            .joined(separator: ", ")

        return ResolvedPlace(
            coordinate: Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude),
            displayName: displayName.isEmpty ? addressString : displayName
        )
    }
}
