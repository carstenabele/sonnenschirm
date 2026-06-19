import Foundation
import CoreLocation
import Combine

/// Provides device GPS coordinates via CoreLocation.
/// Falls back to Frankfurt (50.11°N, 8.68°E) until the first location fix.
final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {

    // MARK: - Published

    @Published var coordinate: (lat: Double, lng: Double) = (lat: 50.11, lng: 8.68)

    // MARK: - Private

    private let manager = CLLocationManager()

    // MARK: - Init

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    // MARK: - Public API

    /// Request authorisation and begin location updates.
    func start() {
        manager.requestWhenInUseAuthorization()
        // Only start updating if already authorized (covers app restart case).
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let coord = location.coordinate
        DispatchQueue.main.async { [weak self] in
            self?.coordinate = (lat: coord.latitude, lng: coord.longitude)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Retain Frankfurt fallback; no user-visible error needed at this layer.
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Start location updates once the user grants permission.
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
}
