import Foundation
import CoreLocation

@MainActor
protocol LocationServiceProtocol {
    var currentLocation: CLLocationCoordinate2D? { get }
    var authorizationStatus: CLAuthorizationStatus { get }
    func requestPermission()
    func startUpdatingLocation()
    func stopUpdatingLocation()
}

@MainActor
final class LocationService: NSObject, LocationServiceProtocol {
    private let locationManager = CLLocationManager()

    private(set) var currentLocation: CLLocationCoordinate2D?
    var authorizationStatus: CLAuthorizationStatus {
        locationManager.authorizationStatus
    }

    var onLocationUpdate: ((CLLocationCoordinate2D) -> Void)?
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = location.coordinate
            self.onLocationUpdate?(location.coordinate)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.onAuthorizationChange?(manager.authorizationStatus)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
}
