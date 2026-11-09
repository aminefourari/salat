import CoreLocation
import Observation

struct ResolvedLocation: Codable, Equatable, Sendable {
    enum Source: String, Codable, Sendable { case gps, manual, lastKnown }
    var lat, lon: Double
    var city: City?
    var source: Source
}

/// Manual city if chosen, else the current GPS fix, else the last known fix, else any manual city. Never (0, 0).
func resolveLocation(gps: CLLocation?, authorized: Bool, manual: City?, useManual: Bool, lastKnown: ResolvedLocation?) -> ResolvedLocation? {
    let fromCity = { (c: City) in ResolvedLocation(lat: c.lat, lon: c.lon, city: c, source: .manual) }
    if useManual, let m = manual { return fromCity(m) }
    if authorized, let g = gps {
        let (lat, lon) = (g.coordinate.latitude, g.coordinate.longitude)
        return ResolvedLocation(lat: lat, lon: lon, city: CityIndex.shared.nearest(lat: lat, lon: lon), source: .gps)
    }
    if let l = lastKnown { return ResolvedLocation(lat: l.lat, lon: l.lon, city: l.city, source: .lastKnown) }
    return manual.map(fromCity)
}

@MainActor @Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var location: CLLocation?
    private(set) var status: CLAuthorizationStatus = .notDetermined
    var authorized: Bool { status == .authorizedAlways || status == .authorized }
    var onChange: (() -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        status = manager.authorizationStatus
    }

    func requestOnce() {
        if status == .notDetermined { manager.requestWhenInUseAuthorization() }
        manager.requestLocation()
    }

    nonisolated func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let l = locs.last else { return }
        Task { @MainActor in
            // Ignore moves under ~5 km, like the web app: same city, same times.
            if let old = self.location, old.distance(from: l) < 5_000 { return }
            self.location = l
            self.onChange?()
        }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {}

    nonisolated func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        let s = m.authorizationStatus
        Task { @MainActor in
            self.status = s
            if self.authorized { self.manager.requestLocation() }
            self.onChange?()
        }
    }
}
