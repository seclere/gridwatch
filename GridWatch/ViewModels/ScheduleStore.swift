import SwiftUI
import Combine

@MainActor
class ScheduleStore: ObservableObject {
    @Published var entries: [ScheduleEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?
    @Published var averageKwh: Double? = nil

    // ─── PASTE YOUR PUBLISHED SHEET URL HERE ──────────────────────────
    private let sheetURL = URL(string:
        "https://docs.google.com/spreadsheets/d/e/2PACX-1vRyjf3h29UnccCcrTrhGbh38Rxa1mE_x2Yz9H2darrwqKgou5_sZvVoWuftloU8-U9V_DHIKJawYqJ5/pub?gid=353401628&single=true&output=csv"
    )!
    // ──────────────────────────────────────────────────────────────────

    // Set to true if your sheet has a header row (hour, priceMWh), false if raw data only
    private let hasHeaderRow = true

    init() {
        entries = Self.placeholderEntries()
        Task { await fetchSchedule() }
    }

    // MARK: - Fetch from Google Sheets

    func fetchSchedule() async {
        isLoading = true
        errorMessage = nil
        do {
            let (data, _) = try await URLSession.shared.data(from: sheetURL)
            guard let csv = String(data: data, encoding: .utf8) else {
                throw URLError(.cannotDecodeContentData)
            }
            let parsed = parseCSV(csv)
            if !parsed.isEmpty {
                entries = parsed
                lastUpdated = Date()
            }
            // B27 = row index 26 in the raw CSV (0-indexed, header is row 0)
            averageKwh = readCell(csv: csv, rowIndex: 26, colIndex: 1)
            print("[ScheduleStore] averageKwh from B27 = \(String(describing: averageKwh))")
        } catch {
            errorMessage = "Could not load schedule: \(error.localizedDescription)"
        }
        isLoading = false
    }

    /// Read a specific cell from the raw CSV by row/col index (0-based).
    private func readCell(csv: String, rowIndex: Int, colIndex: Int) -> Double? {
        let normalised = csv.replacingOccurrences(of: "\r\n", with: "\n")
                            .replacingOccurrences(of: "\r", with: "\n")
        let rows = normalised.components(separatedBy: "\n")
        guard rowIndex < rows.count else { return nil }
        let cols = splitCSVRow(rows[rowIndex])
        guard colIndex < cols.count else { return nil }
        let raw = cols[colIndex]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "₱", with: "")
        return Double(raw)
    }

    // MARK: - CSV Parser
    // Handles Google Sheets quirks:
    //   • Quoted fields:       "2,708.86"  → 2708.86
    //   • Comma-formatted:      2,708.86   → 2708.86
    //   • Negative values:     -10,165.70  → -10165.70
    //   • Windows line endings: \r\n       → \n
    //   • Decimal prices:       2708.86    → stored as Double

    private func parseCSV(_ csv: String) -> [ScheduleEntry] {
        // Normalise line endings
        let normalised = csv.replacingOccurrences(of: "\r\n", with: "\n")
                            .replacingOccurrences(of: "\r", with: "\n")
        var rows = normalised.components(separatedBy: "\n")
        if hasHeaderRow && !rows.isEmpty { rows = Array(rows.dropFirst()) }

        var parsed: [ScheduleEntry] = []
        for row in rows {
            let trimmed = row.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let cols = splitCSVRow(trimmed)
            guard cols.count >= 2 else { continue }

            let hourStr  = cols[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let priceStr = cols[1].trimmingCharacters(in: .whitespacesAndNewlines)
                                  .replacingOccurrences(of: "\"", with: "")  // strip quotes
                                  .replacingOccurrences(of: ",", with: "")   // strip thousand-sep commas
                                  .replacingOccurrences(of: "₱", with: "")   // strip currency symbol if any

            guard
                let hour  = Int(hourStr),
                (0...23).contains(hour),
                let price = Double(priceStr)
            else { continue }

            parsed.append(ScheduleEntry(hour: hour, priceMWh: price))
        }
        return parsed.sorted { $0.hour < $1.hour }
    }

    // Splits a CSV row respecting quoted fields like "2,708.86"
    private func splitCSVRow(_ row: String) -> [String] {
        var cols: [String] = []
        var current = ""
        var inQuotes = false
        for char in row {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                cols.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        cols.append(current)
        return cols
    }

    // MARK: - Placeholder shown before first fetch

    static func placeholderEntries() -> [ScheduleEntry] {
        let prices: [Double] = [
            1.800, 1.750, 1.700, 1.720,
            2.100, 3.200, 4.800, 5.600,
            6.200, 7.100, 7.800, 8.200,
            8.500, 8.300, 8.100, 8.400,
            8.600, 8.200, 7.500, 6.800,
            5.200, 3.800, 2.600, 2.100
        ]
        return prices.enumerated().map { ScheduleEntry(hour: $0.offset, priceMWh: $0.element) }
    }
}
