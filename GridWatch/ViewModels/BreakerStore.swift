import SwiftUI
import Combine

@MainActor
class BreakerStore: ObservableObject {
    @Published var deviceID: String = ""
    @Published var status: BreakerStatus = BreakerStatus()
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let deviceIDKey = "gw_breaker_device_id"
    private var pollingTask: Task<Void, Never>?

    init() {
        deviceID = UserDefaults.standard.string(forKey: deviceIDKey) ?? ""
        if !deviceID.isEmpty { startPolling() }
    }

    deinit { pollingTask?.cancel() }

    func saveDeviceID(_ id: String) {
        deviceID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(deviceID, forKey: deviceIDKey)
        pollingTask?.cancel()
        if !deviceID.isEmpty {
            Task { await fetchStatus() }
            startPolling()
        }
    }

    func fetchStatus() async {
        guard !deviceID.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        do {
            status = try await TuyaService.shared.fetchBreakerStatus(deviceID: deviceID)
        } catch {
            errorMessage = error.localizedDescription
            print("[BreakerStore] fetch failed: \(error)")
        }
        isLoading = false
    }

    private func startPolling() {
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30s
                guard !Task.isCancelled else { break }
                await self?.fetchStatus()
            }
        }
    }
}
