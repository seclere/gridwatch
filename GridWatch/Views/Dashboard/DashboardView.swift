import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var priceVM: PriceViewModel
    @EnvironmentObject var socketStore: SocketStore
    @EnvironmentObject var scheduleStore: ScheduleStore

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HeroHeaderView()
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        TallyCard(label: "On-Peak Hours",
                                  value: "\(priceVM.onPeakCount(schedule: scheduleStore.entries))",
                                  color: .red)
                        TallyCard(label: "Off-Peak Hours",
                                  value: "\(priceVM.offPeakCount(schedule: scheduleStore.entries))",
                                  color: .green)
                    }

                    if let avg = scheduleStore.averageKwh {
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Today's average")
                                    .font(.caption).foregroundStyle(.secondary)
                                HStack(alignment: .firstTextBaseline, spacing: 3) {
                                    Text(String(format: "₱%.3f", avg))
                                        .font(.system(size: 22, weight: .bold, design: .rounded))
                                    Text("/ kWh").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Peak threshold")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text(String(format: "₱%.2f", priceVM.peakThresholdKwh))
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    if let next = priceVM.nextOffPeakHour(schedule: scheduleStore.entries) {
                        InfoRow(label: "Next off-peak window", value: next.hourLabel, valueColor: .green)
                    }

                    BreakerCardView()

                    SocketSummaryCard()
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color(.systemBackground))
    }
}

// MARK: - Hero Header

private struct HeroHeaderView: View {
    @EnvironmentObject var priceVM: PriceViewModel
    @State private var showDebug = false

    private var heroColor: Color {
        priceVM.peakStatus == .onPeak
            ? Color(red: 0.85, green: 0.18, blue: 0.18)
            : Color(red: 0.13, green: 0.55, blue: 0.38)
    }
    private var heroDim: Color {
        priceVM.peakStatus == .onPeak
            ? Color(red: 0.65, green: 0.10, blue: 0.10)
            : Color(red: 0.08, green: 0.38, blue: 0.26)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            heroColor.frame(maxWidth: .infinity)

            Circle()
                .fill(heroDim.opacity(0.45))
                .frame(width: 220, height: 220).offset(x: 160, y: -20)
            Circle()
                .fill(heroDim.opacity(0.28))
                .frame(width: 130, height: 130).offset(x: 230, y: 50)
            Circle()
                .fill(heroDim.opacity(0.18))
                .frame(width: 90, height: 90).offset(x: -10, y: -50)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    Text("GridWatch")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    // Debug button
                    Button { showDebug = true } label: {
                        Image(systemName: "ladybug.fill")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.trailing, 8)
                    // Refresh button
                    Button { Task { await priceVM.fetchPrice() } } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                            .rotationEffect(.degrees(priceVM.isLoading ? 360 : 0))
                            .animation(
                                priceVM.isLoading
                                    ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                                    : .default,
                                value: priceVM.isLoading
                            )
                    }
                }
                .padding(.top, 60).padding(.bottom, 20)

                Text("CURRENT LMP · LUZON")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.2).foregroundStyle(.white.opacity(0.7))

                Group {
                    if let price = priceVM.currentPrice {
                        HStack(alignment: .firstTextBaseline, spacing: 5) {
                            Text(price.formattedKwh)
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                            Text("/ kWh")
                                .font(.system(size: 17, weight: .medium)).padding(.bottom, 4)
                        }
                    } else if priceVM.isLoading {
                        ProgressView().tint(.white).frame(height: 56)
                    } else {
                        Text("—").font(.system(size: 48, weight: .bold, design: .rounded))
                    }
                }
                .foregroundStyle(.white).padding(.top, 4)

                HStack(spacing: 10) {
                    PeakBadge(status: priceVM.peakStatus, style: .hero)
                    if let updated = priceVM.lastUpdated {
                        Text("Updated \(updated.formatted(.relative(presentation: .named)))")
                            .font(.caption2).foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.top, 10).padding(.bottom, 28)

                if let err = priceVM.errorMessage {
                    Text(err).font(.caption).foregroundStyle(.white.opacity(0.8)).padding(.bottom, 8)
                }
            }
            .padding(.horizontal, 20)
        }
        .clipped()
        .animation(.easeInOut(duration: 0.5), value: priceVM.peakStatus == .onPeak)
        .sheet(isPresented: $showDebug) {
            DebugMenuView()
        }
    }
}

// MARK: - Cards

private struct TallyCard: View {
    let label: String; let value: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text("today").font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct InfoRow: View {
    let label: String; let value: String; let valueColor: Color
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.headline).foregroundStyle(valueColor)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct SocketSummaryCard: View {
    @EnvironmentObject var socketStore: SocketStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SOCKETS").font(.caption).fontWeight(.semibold)
                .foregroundStyle(.secondary).padding(.bottom, 8)

            ForEach(socketStore.sockets.prefix(4)) { socket in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(socket.name).font(.subheadline).fontWeight(.medium)
                        Text(socket.location).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let watts = socket.currentWatts, socket.isPowered {
                        HStack(spacing: 3) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 10)).foregroundStyle(.yellow)
                            Text(String(format: "%.0fW", watts))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(.yellow)
                        }
                        .padding(.trailing, 6)
                    }
                    Text(socket.isPowered ? "ON" : "OFF")
                        .font(.caption).fontWeight(.bold)
                        .foregroundStyle(socket.isPowered ? .green : .red)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background((socket.isPowered ? Color.green : Color.red).opacity(0.15))
                        .clipShape(Capsule())
                }
                .padding(.vertical, 8)
                if socket.id != socketStore.sockets.prefix(4).last?.id { Divider() }
            }

            if socketStore.sockets.count > 4 {
                Text("+ \(socketStore.sockets.count - 4) more — tap Sockets to manage")
                    .font(.caption).foregroundStyle(.secondary).padding(.top, 6)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Shared PeakBadge

enum PeakBadgeStyle { case standard, hero }

struct PeakBadge: View {
    let status: PeakStatus
    var style: PeakBadgeStyle = .standard

    private var fg: Color {
        switch style {
        case .standard: return status == .onPeak ? .red : .green
        case .hero:     return .white
        }
    }
    private var bg: Color {
        switch style {
        case .standard: return (status == .onPeak ? Color.red : Color.green).opacity(0.12)
        case .hero:     return .white.opacity(0.20)
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(fg).frame(width: 7, height: 7)
            Text(status.label).font(.subheadline).fontWeight(.semibold).foregroundStyle(fg)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(bg).clipShape(Capsule())
    }
}

#Preview {
    DashboardView()
        .environmentObject(PriceViewModel())
        .environmentObject(SocketStore())
        .environmentObject(ScheduleStore())
        .environmentObject(BreakerStore())
}
