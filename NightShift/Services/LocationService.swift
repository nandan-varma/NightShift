import CoreLocation
import Combine

/// Wraps CLLocationManager for a one-shot, on-demand location fix.
/// Uses `requestLocation()` rather than continuous updates since this app
/// only needs an occasional fix to compute sunrise/sunset, minimizing
/// battery and privacy footprint.
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var currentCoordinate: Coordinate?
    @Published private(set) var lastError: Error?

    private let manager: CLLocationManager

    override init() {
        manager = CLLocationManager()
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    func requestAuthorizationAndLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    func refreshLocation() {
        guard manager.authorizationStatus == .authorizedAlways else { return }
        manager.requestLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentCoordinate = Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        lastError = error
    }
}
