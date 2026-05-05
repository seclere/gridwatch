//
//  BreakerStatus.swift
//  GridWatch
//
//  Created by Ysrael Salces on 5/5/26.
//


import Foundation

struct BreakerStatus {
    var totalKwh: Double?       // DP 105: cumulative energy, unit 0.01 kWh
    var currentWatts: Double?   // DP 103: power, unit 0.1W
    var voltage: Double?        // DP 101: voltage, unit 0.1V
    var current: Double?        // DP 102: current, unit mA
    var isOn: Bool = true       // DP 16: switch
    var lastUpdated: Date?

    var formattedKwh: String {
        guard let kwh = totalKwh else { return "—" }
        return String(format: "%.2f kWh", kwh)
    }
    var formattedWatts: String {
        guard let w = currentWatts else { return "—" }
        return w >= 1000 ? String(format: "%.2f kW", w / 1000) : String(format: "%.0f W", w)
    }
    var formattedVoltage: String {
        guard let v = voltage else { return "—" }
        return String(format: "%.1f V", v)
    }
    var formattedCurrent: String {
        guard let a = current else { return "—" }
        return String(format: "%.2f A", a / 1000)
    }
}
