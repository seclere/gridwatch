import Foundation

// WESM returns price in ₱/MWh as a plain integer.
// Divide by 1000 to get ₱/kWh.

struct WESMPrice {
    /// Raw value from API (₱/MWh)
    let rawMWh: Int
    /// Converted to ₱/kWh
    var perKwh: Double { Double(rawMWh) / 1000.0 }

    var formattedKwh: String {
        String(format: "₱%.3f", perKwh)
    }
}

// MARK: - Peak Classification

enum PeakStatus {
    case onPeak
    case offPeak

    var label: String {
        switch self {
        case .onPeak:  return "On-Peak"
        case .offPeak: return "Off-Peak"
        }
    }

    var color: String {
        switch self {
        case .onPeak:  return "PeakRed"
        case .offPeak: return "OffPeakGreen"
        }
    }
}

// MARK: - Schedule Entry
// Price is stored as Double in ₱/MWh (e.g. 2708.86).
// WESM prices can be negative during off-peak oversupply — that's normal.

struct ScheduleEntry: Identifiable, Codable {
    let id: UUID
    var hour: Int
    var priceMWh: Double?        // ₱/MWh, can be negative
    var peakOverride: PeakStatus?

    /// Price converted to ₱/kWh
    var priceKwh: Double? {
        guard let p = priceMWh else { return nil }
        return p
    }

    var formattedKwh: String {
        guard let kwh = priceKwh else { return "—" }
        return String(format: "₱%.4f", kwh)
    }

    func peakStatus(threshold: Double) -> PeakStatus {
        if let override = peakOverride { return override }
        guard let price = priceMWh else { return .offPeak }
        // Negative prices are always off-peak
        return price >= threshold ? .onPeak : .offPeak
    }

    var hourLabel: String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let suffix = hour < 12 ? "AM" : "PM"
        return "\(h):00 \(suffix)"
    }

    init(hour: Int, priceMWh: Double? = nil, peakOverride: PeakStatus? = nil) {
        self.id = UUID()
        self.hour = hour
        self.priceMWh = priceMWh
        self.peakOverride = peakOverride
    }
}

extension PeakStatus: Codable {
    enum CodingKeys: String, CodingKey { case rawValue }
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = raw == "onPeak" ? .onPeak : .offPeak
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self == .onPeak ? "onPeak" : "offPeak")
    }
}
