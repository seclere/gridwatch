import SwiftUI

struct DebugMenuView: View {
    @EnvironmentObject var priceVM: PriceViewModel
    @EnvironmentObject var socketStore: SocketStore
    @Environment(\.dismiss) var dismiss

    @State private var lastAction: String? = nil
    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            List {

                // MARK: - Current State
                Section("CURRENT STATE") {
                    LabeledContent("Peak Status") {
                        PeakBadge(status: priceVM.peakStatus)
                    }
                    if let price = priceVM.currentPrice {
                        LabeledContent("Live Price", value: price.formattedKwh + " / kWh")
                    }
                    LabeledContent("Threshold") {
                        Text(String(format: "₱%.2f / kWh", priceVM.peakThresholdKwh))
                            .foregroundStyle(.orange)
                    }
                    LabeledContent("Sockets online") {
                        Text("\(socketStore.sockets.filter { !$0.tuyaDeviceID.isEmpty }.count) / \(socketStore.sockets.count)")
                    }
                }

                // MARK: - Force Peak Status
                Section {
                    Button {
                        priceVM.peakStatus = .onPeak
                        socketStore.applyPeakPolicy(status: .onPeak)
                        lastAction = "Forced ON-PEAK — non-essential sockets turned off"
                    } label: {
                        HStack {
                            Image(systemName: "bolt.fill").foregroundStyle(.red)
                            Text("Force On-Peak").foregroundStyle(.red)
                        }
                    }

                    Button {
                        priceVM.peakStatus = .offPeak
                        socketStore.applyPeakPolicy(status: .offPeak)
                        lastAction = "Forced OFF-PEAK — auto-managed sockets turned on"
                    } label: {
                        HStack {
                            Image(systemName: "bolt").foregroundStyle(.green)
                            Text("Force Off-Peak").foregroundStyle(.green)
                        }
                    }
                } header: {
                    Text("FORCE PEAK POLICY")
                } footer: {
                    Text("Immediately applies the peak policy to all sockets without waiting for the price threshold.")
                }

                // MARK: - Individual Socket Control
                Section("SOCKET CONTROL") {
                    ForEach(socketStore.sockets) { socket in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(socket.name).font(.subheadline).fontWeight(.medium)
                                Text(socket.tuyaDeviceID.isEmpty ? "No device ID" : socket.tuyaDeviceID.prefix(16) + "...")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            HStack(spacing: 8) {
                                Button {
                                    if socket.isPowered { return }
                                    socketStore.togglePower(socket: socket)
                                    lastAction = "Sent ON to \(socket.name)"
                                } label: {
                                    Text("ON")
                                        .font(.caption).fontWeight(.bold)
                                        .padding(.horizontal, 10).padding(.vertical, 5)
                                        .background(socket.isPowered ? Color.green : Color(.tertiarySystemBackground))
                                        .foregroundStyle(socket.isPowered ? .white : .secondary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)

                                Button {
                                    if !socket.isPowered { return }
                                    socketStore.togglePower(socket: socket)
                                    lastAction = "Sent OFF to \(socket.name)"
                                } label: {
                                    Text("OFF")
                                        .font(.caption).fontWeight(.bold)
                                        .padding(.horizontal, 10).padding(.vertical, 5)
                                        .background(!socket.isPowered ? Color.red : Color(.tertiarySystemBackground))
                                        .foregroundStyle(!socket.isPowered ? .white : .secondary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                // MARK: - Notifications
                Section {
                    Button {
                        Task {
                            await NotificationService.shared.sendPeakShiftNotification(to: .onPeak, price: 8.421)
                            lastAction = "Sent on-peak notification (check your banner)"
                        }
                    } label: {
                        HStack {
                            Image(systemName: "bell.badge.fill").foregroundStyle(.red)
                            Text("Test On-Peak Notification").foregroundStyle(.red)
                        }
                    }

                    Button {
                        Task {
                            await NotificationService.shared.sendPeakShiftNotification(to: .offPeak, price: 2.451)
                            lastAction = "Sent off-peak notification (check your banner)"
                        }
                    } label: {
                        HStack {
                            Image(systemName: "bell.fill").foregroundStyle(.green)
                            Text("Test Off-Peak Notification").foregroundStyle(.green)
                        }
                    }
                } header: {
                    Text("NOTIFICATIONS")
                } footer: {
                    Text("Fires a notification immediately. If the app is in the foreground it'll appear as a banner. To test the tap-to-apply flow, background the app first then tap the notification.")
                }

                // MARK: - Refresh
                Section("DATA") {
                    Button {
                        Task {
                            isRefreshing = true
                            await priceVM.fetchPrice()
                            await socketStore.refreshPowerReadings()
                            isRefreshing = false
                            lastAction = "Refreshed price + power readings"
                        }
                    } label: {
                        HStack {
                            if isRefreshing {
                                ProgressView().padding(.trailing, 4)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            Text(isRefreshing ? "Refreshing..." : "Refresh price + power now")
                        }
                    }
                    .disabled(isRefreshing)
                }

                // MARK: - Last Action Log
                if let action = lastAction {
                    Section("LAST ACTION") {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            Text(action).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Debug Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    DebugMenuView()
        .environmentObject(PriceViewModel())
        .environmentObject(SocketStore())
}
