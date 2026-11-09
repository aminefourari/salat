import Adhan

// Port of apps/web/src/lib/methods.ts + paramsFor in prayer.ts. Keep both in sync:
// change one → port it here → `UPDATE_MAC_DATA=1 npm test` → `npm run mac:test`.

enum MethodId: String, CaseIterable, Codable, Sendable {
    case aachen, morocco, mwl, ummalqura, uoif, isna, egyptian, karachi, dubai, kuwait, qatar, singapore, turkey, tehran
}

enum AsrSchool: String, CaseIterable, Codable, Sendable { case standard, hanafi }

// One entry per country; anything missing falls back to Muslim World League.
private let byCountry: [String: MethodId] = [
    "DE": .aachen, "MA": .morocco, "SA": .ummalqura, "FR": .uoif, "US": .isna, "CA": .isna,
    "EG": .egyptian, "PK": .karachi, "AE": .dubai, "KW": .kuwait, "QA": .qatar,
    "SG": .singapore, "MY": .singapore, "ID": .singapore, "TR": .turkey, "IR": .tehran,
]

func methodForCountry(_ iso2: String?) -> MethodId { iso2.flatMap { byCountry[$0] } ?? .mwl }

private func custom(_ fajr: Double, _ isha: Double) -> CalculationParameters {
    var p = CalculationMethod.other.params // adhan-swift's angle initialisers are internal
    p.fajrAngle = fajr
    p.ishaAngle = isha
    return p
}

func params(for id: MethodId, asr: AsrSchool, margins: Bool = true) -> CalculationParameters {
    var p: CalculationParameters
    switch id {
    case .aachen:
        // Matches Muslim Pro's "Islamic Center Aachen" (Isha −3), plus the center's Diyanet safety margins.
        p = custom(18, 17)
        p.adjustments.isha = -3
        if margins { p.adjustments.sunrise = -7; p.adjustments.dhuhr = 5; p.adjustments.asr = 4; p.adjustments.maghrib = 7 }
    case .morocco: p = custom(19, 17)
    case .uoif: p = custom(12, 12)
    case .mwl: p = CalculationMethod.muslimWorldLeague.params
    case .ummalqura: p = CalculationMethod.ummAlQura.params
    case .isna: p = CalculationMethod.northAmerica.params
    case .egyptian: p = CalculationMethod.egyptian.params
    case .karachi: p = CalculationMethod.karachi.params
    case .dubai: p = CalculationMethod.dubai.params
    case .kuwait: p = CalculationMethod.kuwait.params
    case .qatar: p = CalculationMethod.qatar.params
    case .singapore: p = CalculationMethod.singapore.params
    case .turkey: p = CalculationMethod.turkey.params
    case .tehran: p = CalculationMethod.tehran.params
    }
    p.highLatitudeRule = .twilightAngle
    p.madhab = asr == .hanafi ? .hanafi : .shafi
    return p
}
