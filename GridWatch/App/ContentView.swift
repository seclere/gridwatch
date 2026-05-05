import SwiftUI

struct ContentView: View {
    @State private var currentPage = 1

    private let tabs: [(label: String, icon: String, activeIcon: String)] = [
        ("Sockets",   "powerplug",           "powerplug.fill"),
        ("Dashboard", "bolt.circle",         "bolt.circle.fill"),
        ("Schedule",  "chart.bar",           "chart.bar.fill")
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Pages — fills all space above the nav bar
            TabView(selection: $currentPage) {
                SocketsView().tag(0)
                DashboardView().tag(1)
                ScheduleView().tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.25), value: currentPage)

            // Custom bottom nav bar
            HStack(spacing: 0) {
                ForEach(tabs.indices, id: \.self) { i in
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            currentPage = i
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: currentPage == i ? tabs[i].activeIcon : tabs[i].icon)
                                .font(.system(size: 22))
                                .symbolEffect(.bounce, value: currentPage == i)
                            Text(tabs[i].label)
                                .font(.system(size: 10, weight: currentPage == i ? .semibold : .regular))
                        }
                        .foregroundStyle(currentPage == i ? Color.accentColor : Color(.tertiaryLabel))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) {
                Divider()
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

#Preview {
    ContentView()
        .environmentObject(PriceViewModel())
        .environmentObject(SocketStore())
        .environmentObject(ScheduleStore())
}
