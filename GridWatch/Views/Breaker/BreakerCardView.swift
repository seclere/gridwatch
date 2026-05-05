//
//  BreakerCardView.swift
//  GridWatch
//
//  Created by Ysrael Salces on 5/5/26.
//


import SwiftUI

// MARK: - Breaker Card (shown on Dashboard)

struct BreakerCardView: View {
    @EnvironmentObject var breakerStore: BreakerStore
    @State private var showSettings = false

    var body: some View {
        Button { showSettings = true } label: {
            VStack(alignment: .leading, spacing: 12) {

                // Header row
                HStack {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.yellow.opacity(0.15))
                                .frame(width: 32, height: 32)
                            Image(systemName: "bolt.horizontal.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.yellow)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Main Breaker")
                                .font(.subheadline).fontWeight(.semibold)
                            Text("KWS-302WF")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if breakerStore.isLoading {
                        ProgressView().scaleEffect(0.7)
                    } else if breakerStore.deviceID.isEmpty {
                        Text("Tap to set up")
                            .font(.caption).foregroundStyle(.secondary)
                    } else if let updated = breakerStore.status.lastUpdated {
                        Text(updated.formatted(.relative(presentation: .named)))
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption).foregroundStyle(.tertiary)
                        .padding(.leading, 4)
                }

                if breakerStore.deviceID.isEmpty {
                    // Not configured
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundStyle(.secondary)
                        Text("No device ID set. Tap to configure.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    // Stats grid
                    HStack(spacing: 0) {
                        StatCell(label: "Total Used",
                                 value: breakerStore.status.formattedKwh,
                                 icon: "sum",
                                 color: .blue)
                        Divider().frame(height: 36)
                        StatCell(label: "Live Power",
                                 value: breakerStore.status.formattedWatts,
                                 icon: "bolt.fill",
                                 color: .yellow)
                        Divider().frame(height: 36)
                        StatCell(label: "Voltage",
                                 value: breakerStore.status.formattedVoltage,
                                 icon: "waveform",
                                 color: .orange)
                        Divider().frame(height: 36)
                        StatCell(label: "Current",
                                 value: breakerStore.status.formattedCurrent,
                                 icon: "arrow.right.circle",
                                 color: .purple)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSettings) {
            BreakerSettingsView()
        }
    }
}

// MARK: - Stat Cell

private struct StatCell: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(value == "—" ? .tertiary : .primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Breaker Settings Sheet

struct BreakerSettingsView: View {
    @EnvironmentObject var breakerStore: BreakerStore
    @Environment(\.dismiss) var dismiss
    @State private var deviceIDInput: String = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Paste device ID", text: $deviceIDInput)
                        .font(.system(.body, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("DEVICE ID")
                } footer: {
                    Text("Find this in iot.tuya.com → your project → Devices tab. The KWS-302WF should appear there once paired in Smart Life.")
                }

                if breakerStore.deviceID.isEmpty == false {
                    Section("LAST READING") {
                        LabeledContent("Total consumed", value: breakerStore.status.formattedKwh)
                        LabeledContent("Live power", value: breakerStore.status.formattedWatts)
                        LabeledContent("Voltage", value: breakerStore.status.formattedVoltage)
                        LabeledContent("Current", value: breakerStore.status.formattedCurrent)
                        if let updated = breakerStore.status.lastUpdated {
                            LabeledContent("Updated") {
                                Text(updated.formatted(.relative(presentation: .named)))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section {
                        Button {
                            Task { await breakerStore.fetchStatus() }
                        } label: {
                            HStack {
                                if breakerStore.isLoading { ProgressView().padding(.trailing, 4) }
                                Text(breakerStore.isLoading ? "Refreshing..." : "Refresh now")
                            }
                        }
                        .disabled(breakerStore.isLoading)
                    }

                    if let err = breakerStore.errorMessage {
                        Section {
                            Label(err, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Main Breaker")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { deviceIDInput = breakerStore.deviceID }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        breakerStore.saveDeviceID(deviceIDInput)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(deviceIDInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    BreakerCardView()
        .environmentObject(BreakerStore())
        .padding()
}