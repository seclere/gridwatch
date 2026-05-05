import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var scheduleStore: ScheduleStore
    @EnvironmentObject var priceVM: PriceViewModel

    private var currentHour: Int { Calendar.current.component(.hour, from: Date()) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ScheduleHeaderView()
                VStack(spacing: 14) {
                    // Bar chart
                    VStack(spacing: 0) {
                        Text("24-hr overview")
                            .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 8)
                        PriceBarChart(entries: scheduleStore.entries,
                                      threshold: priceVM.peakThresholdKwh,
                                      currentHour: currentHour)
                            .padding(.horizontal, 14).padding(.bottom, 14)
                    }
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Threshold slider
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Peak threshold").font(.subheadline).fontWeight(.semibold)
                                if let avg = scheduleStore.averageKwh {
                                    Text("Today's avg: " + String(format: "₱%.3f / kWh", avg))
                                        .font(.caption).foregroundStyle(.secondary)
                                } else {
                                    Text("Hours above this price are on-peak")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "₱%.2f", priceVM.peakThresholdKwh))
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(.orange)
                                if let avg = scheduleStore.averageKwh,
                                   abs(priceVM.peakThresholdKwh - (avg * 4).rounded(.up) / 4) < 0.01 {
                                    Text("auto-set").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                        Slider(value: $priceVM.peakThresholdKwh, in: 1...20, step: 0.25).tint(.orange)
                        if let avg = scheduleStore.averageKwh {
                            Button {
                                priceVM.peakThresholdKwh = (avg * 4).rounded(.up) / 4
                            } label: {
                                Label("Reset to today's average", systemImage: "arrow.counterclockwise")
                                    .font(.caption)
                            }
                            .foregroundStyle(.orange)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Hour table
                    VStack(spacing: 0) {
                        ForEach(scheduleStore.entries) { entry in
                            HourRow(entry: entry, threshold: priceVM.peakThresholdKwh,
                                    isNow: entry.hour == currentHour)
                            if entry.hour != 23 { Divider().padding(.leading, 60) }
                        }
                    }
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 24)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color(.systemBackground))
    }
}

// MARK: - Schedule Header

private struct ScheduleHeaderView: View {
    @EnvironmentObject var scheduleStore: ScheduleStore
    @EnvironmentObject var priceVM: PriceViewModel

    private var onPeakCount: Int {
        scheduleStore.entries.filter { $0.peakStatus(threshold: priceVM.peakThresholdKwh) == .onPeak }.count
    }
    private var offPeakCount: Int { 24 - onPeakCount }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color(red: 0.12, green: 0.28, blue: 0.35).frame(maxWidth: .infinity)
            Circle().fill(Color(red: 0.08, green: 0.20, blue: 0.26).opacity(0.6))
                .frame(width: 180, height: 180).offset(x: 170, y: -10)
            Circle().fill(Color(red: 0.08, green: 0.20, blue: 0.26).opacity(0.4))
                .frame(width: 100, height: 100).offset(x: 250, y: 40)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Schedule").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    // Just refresh directly — no popup
                    Button {
                        Task { await scheduleStore.fetchSchedule() }
                    } label: {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white.opacity(0.9))
                            .rotationEffect(.degrees(scheduleStore.isLoading ? 360 : 0))
                            .animation(
                                scheduleStore.isLoading
                                    ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                                    : .default,
                                value: scheduleStore.isLoading
                            )
                    }
                }
                .padding(.top, 60).padding(.bottom, 16)

                Text("TODAY'S PRICING").font(.system(size: 11, weight: .semibold))
                    .tracking(1.2).foregroundStyle(.white.opacity(0.6))

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(onPeakCount)")
                        .font(.system(size: 48, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text("on-peak hrs")
                        .font(.system(size: 17, weight: .medium)).foregroundStyle(.white.opacity(0.7)).padding(.bottom, 4)
                }
                .padding(.top, 4)

                HStack(spacing: 10) {
                    statPill("\(offPeakCount)", "off-peak", .green)
                    if let updated = scheduleStore.lastUpdated {
                        Text("Updated \(updated.formatted(.relative(presentation: .named)))")
                            .font(.caption2).foregroundStyle(.white.opacity(0.5))
                    }
                    if scheduleStore.isLoading {
                        ProgressView().tint(.white).scaleEffect(0.7)
                    }
                }
                .padding(.top, 10).padding(.bottom, 28)
            }
            .padding(.horizontal, 20)
        }
        .clipped()
    }

    private func statPill(_ value: String, _ label: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Text(value).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white)
            Text(label).font(.system(size: 12)).foregroundStyle(.white.opacity(0.65))
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(.white.opacity(0.15)).clipShape(Capsule())
    }
}

// MARK: - Bar Chart

private struct PriceBarChart: View {
    let entries: [ScheduleEntry]; let threshold: Double; let currentHour: Int
    private var maxPrice: Double { entries.compactMap(\.priceMWh).map { abs($0) }.max() ?? 10 }

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(entries) { entry in
                    let price  = entry.priceMWh ?? 0
                    let frac   = maxPrice > 0 ? abs(price) / maxPrice : 0
                    let isPeak = entry.peakStatus(threshold: threshold) == .onPeak
                    let isNow  = entry.hour == currentHour
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isPeak ? Color.red.opacity(isNow ? 1 : 0.75) : Color.green.opacity(isNow ? 1 : 0.75))
                        .frame(height: max(4, 80 * frac))
                        .overlay(isNow ? RoundedRectangle(cornerRadius: 3).stroke(Color.primary.opacity(0.6), lineWidth: 1.5) : nil)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 80)
            HStack(spacing: 0) {
                ForEach(0..<24, id: \.self) { h in
                    Text(h % 6 == 0 ? hourLabel(h) : "").font(.system(size: 9)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }
            HStack(spacing: 14) {
                legendItem(.red, "On-peak"); legendItem(.green, "Off-peak")
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2).stroke(Color.primary.opacity(0.5), lineWidth: 1.5).frame(width: 10, height: 10)
                    Text("Now").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private func hourLabel(_ h: Int) -> String { h == 0 ? "12a" : h < 12 ? "\(h)a" : h == 12 ? "12p" : "\(h-12)p" }
    private func legendItem(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) { Circle().fill(color).frame(width: 8, height: 8); Text(label).font(.caption2).foregroundStyle(.secondary) }
    }
}

// MARK: - Hour Row

private struct HourRow: View {
    let entry: ScheduleEntry; let threshold: Double; let isNow: Bool
    private var status: PeakStatus { entry.peakStatus(threshold: threshold) }
    private var accent: Color { status == .onPeak ? .red : .green }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .center, spacing: 2) {
                Text(entry.hour % 12 == 0 ? "12" : "\(entry.hour % 12)")
                    .font(.system(size: 13, weight: isNow ? .bold : .regular, design: .rounded))
                    .foregroundStyle(isNow ? .primary : .secondary)
                Text(entry.hour < 12 ? "AM" : "PM")
                    .font(.system(size: 9)).foregroundStyle(isNow ? .secondary : .tertiary)
            }
            .frame(width: 36)
            RoundedRectangle(cornerRadius: 2).fill(accent.opacity(isNow ? 1 : 0.5)).frame(width: 3).frame(maxHeight: .infinity)
            if let kwh = entry.priceKwh {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(String(format: "%.3f", kwh))
                            .font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(accent)
                        Text("₱/kWh").font(.system(size: 10)).foregroundStyle(.tertiary)
                    }
                    if isNow { Text("Current hour").font(.system(size: 10)).foregroundStyle(.blue) }
                }
            } else {
                Text("—").foregroundStyle(.tertiary)
            }
            Spacer()
            Text(status.label).font(.caption).fontWeight(.semibold)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(accent.opacity(0.12)).foregroundStyle(accent).clipShape(Capsule())
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(isNow ? Color(.tertiarySystemBackground) : Color.clear)
    }
}

#Preview {
    ScheduleView().environmentObject(ScheduleStore()).environmentObject(PriceViewModel())
}
