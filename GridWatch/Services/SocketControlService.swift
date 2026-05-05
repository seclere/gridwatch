import Foundation

actor SocketControlService {
    static let shared = SocketControlService()

    func setPower(socketName: String, on: Bool) async throws {
        // Look up the device ID by socket name from SmartSocket.tuyaDeviceID
        // This is called from SocketStore which passes the name — we use deviceID directly there now.
        print("[SocketControlService] \(socketName) → \(on ? "ON" : "OFF")")
    }

    /// Called by SocketStore with the actual Tuya Device ID.
    func setPowerByDeviceID(deviceID: String, socketName: String, on: Bool) async throws {
        guard !deviceID.isEmpty else {
            print("[SocketControlService] No device ID set for \(socketName), skipping.")
            return
        }
        try await TuyaService.shared.setPower(deviceID: deviceID, on: on)
    }

    func applyPeakPolicy(sockets: [(id: String, name: String, deviceID: String, shouldAutoControl: Bool)], isOnPeak: Bool) async {
        for socket in sockets {
            guard socket.shouldAutoControl else { continue }
            do {
                try await setPowerByDeviceID(deviceID: socket.deviceID, socketName: socket.name, on: !isOnPeak)
            } catch {
                print("[SocketControlService] Failed to control \(socket.name): \(error)")
            }
        }
    }
}
