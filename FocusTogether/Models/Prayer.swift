import Adhan
import Foundation

enum PrayerName: String, Codable, CaseIterable, Hashable {
    case fajr, dhuhr, asr, maghrib, isha

    var title: String {
        switch self {
        case .fajr: "Fajr"
        case .dhuhr: "Dhuhr"
        case .asr: "Asr"
        case .maghrib: "Maghrib"
        case .isha: "Isha"
        }
    }
}

/// Where and how to calculate Salah times for a routine. Calculated on-device; nothing is sent anywhere.
struct PrayerSettings: Codable, Hashable {
    var latitude: Double
    var longitude: Double
    var placeName: String
    var method: CalculationMethod
    var hanafiAsr: Bool
}

enum PrayerCalculator {
    static func times(for settings: PrayerSettings, on date: Date) -> [PrayerName: Date] {
        let coordinates = Coordinates(latitude: settings.latitude, longitude: settings.longitude)
        var params = settings.method.params
        params.madhab = settings.hanafiAsr ? .hanafi : .shafi
        params.highLatitudeRule = .recommended(for: coordinates)

        let day = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        guard let times = PrayerTimes(coordinates: coordinates, date: day, calculationParameters: params) else { return [:] }
        return [.fajr: times.fajr, .dhuhr: times.dhuhr, .asr: times.asr, .maghrib: times.maghrib, .isha: times.isha]
    }

    /// Methods offered in the picker, most widely used first.
    static let methods: [CalculationMethod] = [
        .muslimWorldLeague, .moonsightingCommittee, .northAmerica, .egyptian, .karachi,
        .ummAlQura, .dubai, .qatar, .kuwait, .singapore, .turkey, .tehran,
    ]

    static func name(of method: CalculationMethod) -> String {
        switch method {
        case .muslimWorldLeague: "Muslim World League"
        case .moonsightingCommittee: "Moonsighting Committee"
        case .northAmerica: "ISNA (North America)"
        case .egyptian: "Egyptian Authority"
        case .karachi: "Karachi (Univ. of Islamic Sciences)"
        case .ummAlQura: "Umm al-Qura (Makkah)"
        case .dubai: "Dubai"
        case .qatar: "Qatar"
        case .kuwait: "Kuwait"
        case .singapore: "Singapore"
        case .turkey: "Turkey (Diyanet)"
        case .tehran: "Tehran"
        case .other: "Other"
        }
    }

    /// A sensible default for the user's country; they can change it.
    static func suggestedMethod(forCountryCode code: String?) -> CalculationMethod {
        switch code?.uppercased() {
        case "GB", "IE": .moonsightingCommittee
        case "US", "CA": .northAmerica
        case "EG", "SD", "LY", "SY", "LB", "JO", "IQ": .egyptian
        case "PK", "IN", "BD", "AF": .karachi
        case "SA", "YE": .ummAlQura
        case "AE": .dubai
        case "QA": .qatar
        case "KW": .kuwait
        case "SG", "MY", "ID", "BN": .singapore
        case "TR": .turkey
        case "IR": .tehran
        default: .muslimWorldLeague
        }
    }
}
