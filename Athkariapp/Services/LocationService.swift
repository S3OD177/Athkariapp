import Foundation
import CoreLocation

extension Notification.Name {
    static let didUpdateLocation = Notification.Name("didUpdateLocation")
    static let didChangeLocationAuthorization = Notification.Name("didChangeLocationAuthorization")
}

@MainActor
protocol LocationServiceProtocol {
    var currentLocation: CLLocationCoordinate2D? { get }
    var authorizationStatus: CLAuthorizationStatus { get }
    func requestPermission()
    func startUpdatingLocation()
    func stopUpdatingLocation()
    func startUpdatingHeading()
    func stopUpdatingHeading()
}

@MainActor
final class LocationService: NSObject, LocationServiceProtocol {
    private let locationManager = CLLocationManager()

    private(set) var currentLocation: CLLocationCoordinate2D?
    var authorizationStatus: CLAuthorizationStatus {
        locationManager.authorizationStatus
    }

    // Deprecated: Use NotificationCenter instead
    var onLocationUpdate: ((CLLocationCoordinate2D) -> Void)?
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
    var onHeadingUpdate: ((CLLocationDirection) -> Void)?

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

    func startUpdatingHeading() {
        locationManager.startUpdatingHeading()
    }

    func stopUpdatingHeading() {
        locationManager.stopUpdatingHeading()
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.currentLocation = location.coordinate
            
            // Post Notification
            NotificationCenter.default.post(
                name: .didUpdateLocation,
                object: nil,
                userInfo: ["location": location]
            )
            
            // Legacy callback support
            self.onLocationUpdate?(location.coordinate)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let heading = newHeading.trueHeading > 0 ? newHeading.trueHeading : newHeading.magneticHeading
        Task { @MainActor in
            self.onHeadingUpdate?(heading)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            NotificationCenter.default.post(
                name: .didChangeLocationAuthorization,
                object: nil,
                userInfo: ["status": status.rawValue] // RawValue for simple passing, or just check service.status
            )
            
            self.onAuthorizationChange?(status)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
}
