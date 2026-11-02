import CoreLocation

struct FoundPlace {
    let coordinate: CLLocationCoordinate2D
    let name: String
    let countryCode: String?
}

enum LocationError: LocalizedError {
    case denied

    var errorDescription: String? {
        "Location access is off. You can allow it in Settings › Lockin › Location."
    }
}

/// Asks for "When In Use" permission if needed and returns one city-level location.
/// Keep an instance alive (e.g. in @State) while a request is in flight.
final class LocationFetcher: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func fetchPlace() async throws -> FoundPlace {
        let location = try await currentLocation()
        let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first
        let name = placemark?.locality ?? placemark?.administrativeArea ?? placemark?.country ?? "Your location"
        return FoundPlace(coordinate: location.coordinate, name: name, countryCode: placemark?.isoCountryCode)
    }

    private func currentLocation() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .denied, .restricted:
                finish(.failure(LocationError.denied))
            default:
                manager.requestLocation()
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard continuation != nil else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            finish(.failure(LocationError.denied))
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last { finish(.success(location)) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(.failure(error))
    }

    private func finish(_ result: Result<CLLocation, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }
}
