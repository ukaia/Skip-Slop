import CoreLocation
import Observation
import os

nonisolated private let locationLogger = Logger(subsystem: "alpha.Skip-Slop", category: "Location")

@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    var location: CLLocation?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    /// Created on first use, so screens that never need location (sample data,
    /// screenshots) never touch Core Location.
    @ObservationIgnored private var _manager: CLLocationManager?

    private var manager: CLLocationManager {
        if let _manager { return _manager }
        let manager = CLLocationManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        // The current status arrives in `locationManagerDidChangeAuthorization`,
        // which fires right after the delegate is set. Reading
        // `manager.authorizationStatus` here would block the main thread.
        _manager = manager
        return manager
    }

    /// Creates the manager so its authorization callback reports the current status.
    func activate() {
        _ = manager
    }

    /// Starts updates if already authorized; otherwise prompts while the status is
    /// still undetermined. Before the first authorization callback the status reads
    /// as undetermined, and asking again is harmless: the system only prompts once,
    /// and the callback starts updates when access is granted.
    func requestPermission() {
        activate()
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            break // denied/restricted — UI offers a link to Settings
        }
    }

    func startUpdating() {
        manager.startUpdatingLocation()
    }

    func stopUpdating() {
        _manager?.stopUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in
            self.location = latest
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if self.isAuthorized {
                self.manager.startUpdatingLocation()
            } else {
                self.manager.stopUpdatingLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Location errors are non-fatal — just log for debugging
        locationLogger.error("Location error: \(error.localizedDescription)")
    }
}
