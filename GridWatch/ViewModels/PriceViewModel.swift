import SwiftUI
import Combine

@MainActor
class PriceViewModel: ObservableObject {
    @Published var currentPrice: WESMPrice?
    @Published var peakStatus: PeakStatus = .offPeak
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?
    @Published var peakThresholdKwh: Double = 5.0

    private var pollingTask: Task<Void, Never>?
    private let pollInterval: TimeInterval = 300   // 5 minutes
    private var previousPeakStatus: PeakStatus? = nil

    private let lastLaunchKey = "gw_last_launch_date"

    init() {
        Task {
            await NotificationService.shared.requestPermission()
            await fetchPrice()
            await triggerFirstLaunchRefreshIfNeeded()
        }
        startPolling()
    }

    /// If this is the first launch today, trigger a fresh price + schedule fetch
    private func triggerFirstLaunchRefreshIfNeeded() async {
        let today = Calendar.current.startOfDay(for: Date())
        let lastLaunch = UserDefaults.standard.object(forKey: lastLaunchKey) as? Date ?? .distantPast
        if lastLaunch < today {
            UserDefaults.standard.set(Date(), forKey: lastLaunchKey)
            await fetchPrice()
        }
    }

    deinit { pollingTask?.cancel() }

    // MARK: - Fetch

    func fetchPrice() async {
        isLoading = true
        errorMessage = nil
        do {
            let price = try await WESMService.shared.fetchCurrentPrice()
            currentPrice = price
            let newStatus: PeakStatus = price.perKwh >= peakThresholdKwh ? .onPeak : .offPeak

            // Detect shift and notify
            if let previous = previousPeakStatus, previous != newStatus {
                await NotificationService.shared.sendPeakShiftNotification(
                    to: newStatus, price: price.perKwh)
            }

            previousPeakStatus = newStatus
            peakStatus = newStatus
            lastUpdated = Date()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Tally helpers

    func onPeakCount(schedule: [ScheduleEntry]) -> Int {
        schedule.filter { $0.peakStatus(threshold: peakThresholdKwh) == .onPeak }.count
    }

    func offPeakCount(schedule: [ScheduleEntry]) -> Int {
        schedule.filter { $0.peakStatus(threshold: peakThresholdKwh) == .offPeak }.count
    }

    func nextOffPeakHour(schedule: [ScheduleEntry]) -> ScheduleEntry? {
        let currentHour = Calendar.current.component(.hour, from: Date())
        return schedule
            .filter { $0.hour > currentHour }
            .first { $0.peakStatus(threshold: peakThresholdKwh) == .offPeak }
    }

    func averageKwh(schedule: [ScheduleEntry]) -> Double? {
        let prices = schedule.compactMap(\.priceKwh)
        guard !prices.isEmpty else { return nil }
        return prices.reduce(0, +) / Double(prices.count)
    }

    func syncThresholdToAverage(schedule: [ScheduleEntry]) {
        guard let avg = averageKwh(schedule: schedule) else { return }
        peakThresholdKwh = (avg * 4).rounded() / 4
    }

    // MARK: - Polling

    private func startPolling() {
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64((self?.pollInterval ?? 300) * 1_000_000_000))
                guard !Task.isCancelled else { break }
                await self?.fetchPrice()
            }
        }
    }
}
