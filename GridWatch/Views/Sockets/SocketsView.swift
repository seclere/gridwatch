import SwiftUI

// MARK: - SocketsView

struct SocketsView: View {
    @EnvironmentObject var socketStore: SocketStore
    @EnvironmentObject var priceVM: PriceViewModel
    @State private var showAddSocket = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    SocketsHeaderView(showAddSocket: $showAddSocket)
                    VStack(spacing: 14) {

                        // Auto-control status
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill((priceVM.peakStatus == .onPeak ? Color.red : Color.green).opacity(0.12))
                                    .frame(width: 44, height: 44)
                                Image(systemName: priceVM.peakStatus == .onPeak ? "bolt.fill" : "bolt")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(priceVM.peakStatus == .onPeak ? .red : .green)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(priceVM.peakStatus == .onPeak ? "Auto-control active" : "Standing by")
                                    .font(.subheadline).fontWeight(.semibold)
                                Text(priceVM.peakStatus == .onPeak
                                     ? "Shiftable & elastic loads switched off"
                                     : "All sockets following manual state")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            PeakBadge(status: priceVM.peakStatus)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        // Socket list
                        if socketStore.sockets.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "powerplug")
                                    .font(.system(size: 36)).foregroundStyle(.tertiary)
                                Text("No sockets yet").font(.subheadline).foregroundStyle(.secondary)
                                Button { showAddSocket = true } label: {
                                    Text("Add your first socket").font(.subheadline).fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 40)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        } else {
                            VStack(spacing: 0) {
                                ForEach(socketStore.sockets) { socket in
                                    NavigationLink(destination: SocketDetailView(socketID: socket.id)) {
                                        SocketRowView(socket: socket)
                                    }
                                    .buttonStyle(.plain)
                                    if socket.id != socketStore.sockets.last?.id {
                                        Divider().padding(.leading, 74)
                                    }
                                }
                            }
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        LoadCategoryLegend()
                    }
                    .padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 24)
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(Color(.systemBackground))
            .navigationBarHidden(true)
            .sheet(isPresented: $showAddSocket) { AddSocketView() }
        }
    }
}

// MARK: - Header

private struct SocketsHeaderView: View {
    @EnvironmentObject var socketStore: SocketStore
    @Binding var showAddSocket: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color(red: 0.13, green: 0.20, blue: 0.42).frame(maxWidth: .infinity)
            Circle().fill(Color(red: 0.09, green: 0.14, blue: 0.32).opacity(0.6))
                .frame(width: 180, height: 180).offset(x: 170, y: -10)
            Circle().fill(Color(red: 0.09, green: 0.14, blue: 0.32).opacity(0.4))
                .frame(width: 100, height: 100).offset(x: 250, y: 40)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Sockets").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    Button { showAddSocket = true } label: {
                        Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundStyle(.white.opacity(0.9))
                    }
                }
                .padding(.top, 60).padding(.bottom, 16)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(socketStore.sockets.count)")
                        .font(.system(size: 48, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text(socketStore.sockets.count == 1 ? "socket" : "sockets")
                        .font(.system(size: 17, weight: .medium)).foregroundStyle(.white.opacity(0.7)).padding(.bottom, 4)
                }
                .padding(.top, 4)
                HStack(spacing: 10) {
                    statPill("\(socketStore.sockets.filter(\.isPowered).count)", "on", .green)
                    statPill("\(socketStore.sockets.filter { !$0.isPowered }.count)", "off", .red)
                    statPill("\(socketStore.sockets.filter(\.hasNonEssentialLoad).count)", "auto", .orange)
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

// MARK: - Socket Row

struct SocketRowView: View {
    @EnvironmentObject var socketStore: SocketStore
    let socket: SmartSocket

    var body: some View {
        HStack(spacing: 14) {
            Button { socketStore.togglePower(socket: socket) } label: {
                ZStack {
                    Circle().fill(socket.isPowered ? Color.green : Color(.tertiarySystemBackground))
                        .frame(width: 44, height: 44)
                    Image(systemName: "power")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(socket.isPowered ? .white : .secondary)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(socket.name).font(.headline).foregroundStyle(.primary)
                    CategoryPill(category: socket.category, compact: true)
                }
                Text(socket.location.isEmpty ? "No location" : socket.location)
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    if !socket.notes.isEmpty {
                        Text(socket.notes).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                    }
                    if let watts = socket.currentWatts, socket.isPowered {
                        if !socket.notes.isEmpty { Text("·").font(.caption2).foregroundStyle(.tertiary) }
                        HStack(spacing: 2) {
                            Image(systemName: "bolt.fill").font(.system(size: 9)).foregroundStyle(.yellow)
                            Text(watts < 1 ? "<1W" : String(format: "%.0fW", watts))
                                .font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(.yellow)
                        }
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}

// MARK: - Socket Detail View
// Passes socketID so edits are reflected live from the store

struct SocketDetailView: View {
    @EnvironmentObject var socketStore: SocketStore
    @Environment(\.dismiss) var dismiss
    let socketID: UUID

    // Local editable copy
    @State private var name: String = ""
    @State private var location: String = ""
    @State private var category: LoadCategory = .fixed
    @State private var notes: String = ""
    @State private var tuyaDeviceID: String = ""
    @State private var showDeleteConfirm = false
    @State private var hasChanges = false

    private var socket: SmartSocket? { socketStore.sockets.first(where: { $0.id == socketID }) }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {

                // Info card
                VStack(spacing: 0) {
                    rowField(label: "Name", text: $name)
                    Divider().padding(.leading, 16)
                    rowField(label: "Location", text: $location)
                    Divider().padding(.leading, 16)
                    rowField(label: "Notes", text: $notes, placeholder: "e.g. Air conditioner, TV")
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Category picker
                VStack(alignment: .leading, spacing: 0) {
                    Text("LOAD CATEGORY")
                        .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)
                    ForEach(LoadCategory.allCases) { cat in
                        Divider().padding(.leading, 16)
                        Button { category = cat; hasChanges = true } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(categoryColor(cat).opacity(0.12))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: cat.icon)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(categoryColor(cat))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cat.rawValue).font(.subheadline).fontWeight(.medium).foregroundStyle(.primary)
                                    Text(cat.description).font(.caption).foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                                if category == cat {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue)
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 4)
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Power + device card
                VStack(spacing: 0) {
                    // Power toggle (reads live from store)
                    if let s = socket {
                        HStack {
                            Text("Power").font(.subheadline).fontWeight(.medium)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { s.isPowered },
                                set: { _ in socketStore.togglePower(socket: s) }
                            )).labelsHidden()
                        }
                        .padding()

                        if s.isPowered {
                            Divider().padding(.leading, 16)
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "bolt.fill").foregroundStyle(.yellow)
                                    Text("Live power").font(.subheadline).fontWeight(.medium)
                                }
                                Spacer()
                                Text(s.formattedWatts)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(wattColor(s.currentWatts))
                            }
                            .padding()

                            Divider().padding(.leading, 16)
                            HStack {
                                HStack(spacing: 6) {
                                    Image(systemName: "sum").foregroundStyle(.blue)
                                    Text("Total consumed").font(.subheadline).fontWeight(.medium)
                                }
                                Spacer()
                                Text(s.formattedKwh)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(.blue)
                            }
                            .padding()
                        }
                    }

                    Divider().padding(.leading, 16)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Tuya Device ID").font(.subheadline).fontWeight(.medium)
                            Spacer()
                            if !tuyaDeviceID.isEmpty {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            }
                            Button {
                                if let str = UIPasteboard.general.string {
                                    tuyaDeviceID = str.trimmingCharacters(in: .whitespacesAndNewlines)
                                }
                            } label: {
                                Label("Paste", systemImage: "doc.on.clipboard")
                                    .font(.caption).fontWeight(.semibold)
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(Color.blue.opacity(0.12))
                                    .foregroundStyle(.blue)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        Text(tuyaDeviceID.isEmpty ? "No device ID set" : tuyaDeviceID)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(tuyaDeviceID.isEmpty ? .tertiary : .secondary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        TextField("Or type device ID here", text: $tuyaDeviceID)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    .padding()
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Delete button
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Label("Delete Socket", systemImage: "trash")
                        .frame(maxWidth: .infinity).padding()
                        .background(Color.red.opacity(0.08))
                        .foregroundStyle(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
        .navigationTitle(name.isEmpty ? "Socket" : name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { saveChanges() }
                    .fontWeight(.semibold)
                    .disabled(!hasChanges)
                    .opacity(hasChanges ? 1 : 0.4)
            }
        }
        .onAppear { loadFromStore() }
        .onChange(of: name)          { _, _ in hasChanges = true }
        .onChange(of: location)      { _, _ in hasChanges = true }
        .onChange(of: notes)         { _, _ in hasChanges = true }
        .onChange(of: tuyaDeviceID)  { _, _ in hasChanges = true }
        .confirmationDialog("Delete \(name)?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Socket", role: .destructive) {
                if let idx = socketStore.sockets.firstIndex(where: { $0.id == socketID }) {
                    socketStore.delete(at: IndexSet([idx]))
                }
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    private func loadFromStore() {
        guard let s = socket else { return }
        name         = s.name
        location     = s.location
        category     = s.category
        notes        = s.notes
        tuyaDeviceID = s.tuyaDeviceID
        hasChanges   = false
    }

    private func saveChanges() {
        guard var s = socket else { return }
        s.name         = name
        s.location     = location
        s.category     = category
        s.notes        = notes
        s.tuyaDeviceID = tuyaDeviceID
        socketStore.update(s)
        hasChanges = false
    }

    private func wattColor(_ watts: Double?) -> Color {
        guard let w = watts else { return .primary }
        return w > 1000 ? .red : w > 500 ? .orange : .primary
    }

    @ViewBuilder
    private func rowField(label: String, text: Binding<String>, placeholder: String = "") -> some View {
        HStack {
            Text(label).font(.subheadline).fontWeight(.medium).frame(width: 80, alignment: .leading)
            TextField(placeholder.isEmpty ? label : placeholder, text: text)
                .font(.subheadline).foregroundStyle(.primary)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}

// MARK: - Category Legend

private struct LoadCategoryLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("LOAD CATEGORIES")
                .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)
            ForEach(Array(LoadCategory.allCases.enumerated()), id: \.element) { i, cat in
                if i > 0 { Divider().padding(.leading, 56) }
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8).fill(categoryColor(cat).opacity(0.12)).frame(width: 36, height: 36)
                        Image(systemName: cat.icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(categoryColor(cat))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(cat.rawValue).font(.subheadline).fontWeight(.medium)
                            if cat.isAutoControllable {
                                Text("auto-off").font(.caption2).fontWeight(.semibold)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.12)).foregroundStyle(.orange).clipShape(Capsule())
                            }
                        }
                        Text(cat.description).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
            }
            .padding(.bottom, 4)
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Category Pill

struct CategoryPill: View {
    let category: LoadCategory
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: category.icon).font(.system(size: compact ? 9 : 11, weight: .semibold))
            if !compact { Text(category.rawValue).font(.caption2).fontWeight(.semibold) }
        }
        .foregroundStyle(categoryColor(category))
        .padding(.horizontal, compact ? 6 : 8).padding(.vertical, compact ? 3 : 4)
        .background(categoryColor(category).opacity(0.12)).clipShape(Capsule())
    }
}

// MARK: - Add Socket

struct AddSocketView: View {
    @EnvironmentObject var socketStore: SocketStore
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var location = ""
    @State private var category: LoadCategory = .fixed
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // Basic info
                    VStack(spacing: 0) {
                        HStack {
                            Text("Name").font(.subheadline).fontWeight(.medium).frame(width: 70, alignment: .leading)
                            TextField("e.g. Socket A", text: $name)
                        }
                        .padding()
                        Divider().padding(.leading, 16)
                        HStack {
                            Text("Location").font(.subheadline).fontWeight(.medium).frame(width: 70, alignment: .leading)
                            TextField("e.g. Living Room", text: $location)
                        }
                        .padding()
                        Divider().padding(.leading, 16)
                        HStack {
                            Text("Notes").font(.subheadline).fontWeight(.medium).frame(width: 70, alignment: .leading)
                            TextField("What's plugged in?", text: $notes)
                        }
                        .padding()
                    }
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Category picker — large cards
                    VStack(alignment: .leading, spacing: 10) {
                        Text("LOAD CATEGORY")
                            .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)

                        ForEach(LoadCategory.allCases) { cat in
                            Button { category = cat } label: {
                                HStack(spacing: 16) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(categoryColor(cat).opacity(category == cat ? 0.2 : 0.08))
                                            .frame(width: 52, height: 52)
                                        Image(systemName: cat.icon)
                                            .font(.system(size: 22, weight: .semibold))
                                            .foregroundStyle(categoryColor(cat))
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(cat.rawValue)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Text(cat.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                        // Preset suggestions
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 6) {
                                                ForEach(cat.presets.prefix(4), id: \.self) { preset in
                                                    Text(preset)
                                                        .font(.system(size: 10, weight: .medium))
                                                        .padding(.horizontal, 8).padding(.vertical, 3)
                                                        .background(categoryColor(cat).opacity(0.08))
                                                        .foregroundStyle(categoryColor(cat))
                                                        .clipShape(Capsule())
                                                }
                                                if cat.presets.count > 4 {
                                                    Text("+\(cat.presets.count - 4) more")
                                                        .font(.system(size: 10))
                                                        .foregroundStyle(.tertiary)
                                                }
                                            }
                                        }
                                    }
                                    Spacer()
                                    Image(systemName: category == cat ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                        .foregroundStyle(category == cat ? categoryColor(cat) : Color(.tertiaryLabel))
                                }
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(category == cat ? categoryColor(cat).opacity(0.4) : Color.clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("New Socket")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        socketStore.add(SmartSocket(
                            name: name.isEmpty ? "New Socket" : name,
                            location: location,
                            category: category,
                            notes: notes))
                        dismiss()
                    }
                    .fontWeight(.semibold).disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Color helper

func categoryColor(_ category: LoadCategory) -> Color {
    switch category {
    case .uninterruptible: return .green
    case .fixed:           return .red
    case .shiftable:       return .blue
    case .elastic:         return .orange
    }
}

#Preview {
    SocketsView()
        .environmentObject(SocketStore())
        .environmentObject(PriceViewModel())
}
