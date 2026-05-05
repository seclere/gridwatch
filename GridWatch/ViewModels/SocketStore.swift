import SwiftUI
import Combine

@MainActor
class SocketStore: ObservableObject {
    @Published var sockets: [SmartSocket] = []
    @Published var isSyncing = false

    private let persistenceKey = "gw_sockets_v1"
    private var pollingTask: Task<Void, Never>?

    init() {
        load()
        if sockets.isEmpty { sockets = SmartSocket.sampleSockets }
        startPowerPolling()
    }

    deinit { pollingTask?.cancel() }

    // MARK: - CRUD

    func add(_ socket: SmartSocket) { sockets.append(socket); save() }

    func update(_ socket: SmartSocket) {
        guard let idx = sockets.firstIndex(where: { $0.id == socket.id }) else { return }
        sockets[idx] = socket; save()
    }

    func delete(at offsets: IndexSet) { sockets.remove(atOffsets: offsets); save() }

    // MARK: - Power Toggle

    func togglePower(socket: SmartSocket) {
        guard let idx = sockets.firstIndex(where: { $0.id == socket.id }) else { return }
        sockets[idx].isPowered.toggle()
        let name     = sockets[idx].name
        let deviceID = sockets[idx].tuyaDeviceID
        let powered  = sockets[idx].isPowered
        print("[SocketStore] togglePower → \(name) deviceID='\(deviceID)' on=\(powered)")
        Task {
            isSyncing = true
            do {
                try await SocketControlService.shared.setPowerByDeviceID(
                    deviceID: deviceID, socketName: name, on: powered)
                print("[SocketStore] ✓ command sent successfully")
            } catch {
                print("[SocketStore] ✗ error: \(error)")
                if let revertIdx = sockets.firstIndex(where: { $0.id == socket.id }) {
                    sockets[revertIdx].isPowered = !powered
                }
            }
            isSyncing = false
        }
    }

    // MARK: - Peak Policy

    func applyPeakPolicy(status: PeakStatus) {
        let payload = sockets.map { (
            id: $0.id.uuidString,
            name: $0.name,
            deviceID: $0.tuyaDeviceID,
            shouldAutoControl: $0.shouldTurnOffOnPeak
        )}
        let isOnPeak = status == .onPeak
        Task {
            isSyncing = true
            await SocketControlService.shared.applyPeakPolicy(sockets: payload, isOnPeak: isOnPeak)
            for idx in sockets.indices {
                if sockets[idx].shouldTurnOffOnPeak {
                    sockets[idx].isPowered = !isOnPeak
                }
            }
            isSyncing = false
        }
        save()
    }

    // MARK: - Power Reading Poll (every 30 seconds)

    private func startPowerPolling() {
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled else { break }
                await self?.refreshPowerReadings()
            }
        }
    }

    func refreshPowerReadings() async {
        for idx in sockets.indices {
            let deviceID = sockets[idx].tuyaDeviceID
            guard !deviceID.isEmpty else { continue }
            do {
                let status = try await TuyaService.shared.fetchStatus(deviceID: deviceID)
                sockets[idx].isPowered    = status.isPowered
                sockets[idx].currentWatts = status.watts
                sockets[idx].totalKwh     = status.totalKwh
            } catch {
                print("[SocketStore] power poll failed for \(sockets[idx].name): \(error)")
            }
        }
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(sockets) {
            UserDefaults.standard.set(data, forKey: persistenceKey)
        }
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: persistenceKey),
            let decoded = try? JSONDecoder().decode([SmartSocket].self, from: data)
        else { return }
        sockets = decoded
    }
}
