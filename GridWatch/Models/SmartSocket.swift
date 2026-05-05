import Foundation

// MARK: - Load Category

enum LoadCategory: String, CaseIterable, Codable, Identifiable {
    case uninterruptible = "Uninterruptible"
    case fixed           = "Fixed Load"
    case shiftable       = "Shiftable Load"
    case elastic         = "Elastic Load"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .uninterruptible: return "Must stay on at all times regardless of pricing."
        case .fixed:           return "Strictly necessary, cannot be delayed without compromising comfort or function."
        case .shiftable:       return "Necessary but the start time can be delayed to take advantage of lower rates."
        case .elastic:         return "Power consumption can be managed, but timing cannot be postponed."
        }
    }

    var icon: String {
        switch self {
        case .uninterruptible: return "lock.fill"
        case .fixed:           return "bolt.fill"
        case .shiftable:       return "clock.arrow.2.circlepath"
        case .elastic:         return "slider.horizontal.3"
        }
    }

    // Priority order: uninterruptible > fixed > shiftable / elastic
    var priority: Int {
        switch self {
        case .uninterruptible: return 0
        case .fixed:           return 1
        case .shiftable:       return 2
        case .elastic:         return 2
        }
    }

    var isAutoControllable: Bool {
        switch self {
        case .uninterruptible: return false
        case .fixed:           return false
        case .shiftable:       return true
        case .elastic:         return true
        }
    }

    var presets: [String] {
        switch self {
        case .uninterruptible:
            return ["Refrigerator", "WiFi / Modem / Router", "Home Assistant"]
        case .fixed:
            return ["Microwave oven", "Induction cooker", "Water heater", "Coffee machine",
                    "Electric griddle", "Deep fryer", "Television", "Shower water heater",
                    "Blower", "Lights"]
        case .shiftable:
            return ["Flat iron", "Cellphone charger", "Rice cooker", "Steamer", "Washing machine"]
        case .elastic:
            return ["Air conditioner", "Electric fan", "Desk fan"]
        }
    }
}

// MARK: - SmartSocket

struct SmartSocket: Identifiable, Codable {
    let id: UUID
    var name: String
    var location: String
    var category: LoadCategory     // single category per socket
    var notes: String              // optional notes (replaces appliance list)
    var isOnline: Bool
    var isPowered: Bool
    var tuyaDeviceID: String
    var currentWatts: Double?      // live watts from Tuya
    var totalKwh: Double?          // cumulative kWh from Tuya

    var shouldTurnOffOnPeak: Bool { category.isAutoControllable }
    // kept for SocketStore compatibility
    var hasNonEssentialLoad: Bool  { category.isAutoControllable }

    var formattedWatts: String {
        guard let w = currentWatts, isPowered else { return "—" }
        return w < 1 ? "< 1 W" : String(format: "%.1f W", w)
    }

    var formattedKwh: String {
        guard let kwh = totalKwh else { return "—" }
        return String(format: "%.3f kWh", kwh)
    }

    init(name: String, location: String = "", category: LoadCategory = .fixed,
         notes: String = "", tuyaDeviceID: String = "") {
        self.id           = UUID()
        self.name         = name
        self.location     = location
        self.category     = category
        self.notes        = notes
        self.tuyaDeviceID = tuyaDeviceID
        self.isOnline     = true
        self.isPowered    = true
    }
}

// MARK: - Sample Data

extension SmartSocket {
    static var sampleSockets: [SmartSocket] { [] }
}
