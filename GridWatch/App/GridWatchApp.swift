import SwiftUI
import UserNotifications
import BackgroundTasks

@main
struct GridWatchApp: App {
    @StateObject private var priceVM       = PriceViewModel()
    @StateObject private var socketStore   = SocketStore()
    @StateObject private var scheduleStore = ScheduleStore()
    @StateObject private var breakerStore  = BreakerStore()

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(priceVM)
                .environmentObject(socketStore)
                .environmentObject(scheduleStore)
                .environmentObject(breakerStore)
                .onChange(of: scheduleStore.averageKwh) { _, avg in
                    guard let avg else { return }
                    priceVM.peakThresholdKwh = (avg * 4).rounded(.up) / 4
                }
                .onReceive(NotificationCenter.default.publisher(for: .didTapPeakNotification)) { note in
                    // User tapped notification — apply policy now
                    if let status = note.object as? PeakStatus {
                        socketStore.applyPeakPolicy(status: status)
                    }
                }
        }
    }
}

// MARK: - App Delegate (background fetch + notification handling)

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        // Register background fetch task
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.gridwatch.pricefetch",
            using: nil
        ) { task in
            self.handleBackgroundFetch(task: task as! BGAppRefreshTask)
        }

        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        scheduleBackgroundFetch()
    }

    private func scheduleBackgroundFetch() {
        let request = BGAppRefreshTaskRequest(identifier: "com.gridwatch.pricefetch")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 5 * 60)  // earliest 5 min from now
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleBackgroundFetch(task: BGAppRefreshTask) {
        scheduleBackgroundFetch()  // reschedule next one

        let fetchTask = Task {
            // Fetch price in background — only sends notification if status changed
            // Socket control is NOT triggered here — user must open the app
            let priceVM = PriceViewModel()
            await priceVM.fetchPrice()
        }

        task.expirationHandler = { fetchTask.cancel() }

        Task {
            await fetchTask.value
            task.setTaskCompleted(success: true)
        }
    }

    // MARK: - Notification tap handler

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 didReceive response: UNNotificationResponse,
                                 withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        if let raw = info["peakStatus"] as? String {
            let status: PeakStatus = raw == "onPeak" ? .onPeak : .offPeak
            // Post to the app — ContentView will call applyPeakPolicy when it receives this
            NotificationCenter.default.post(name: .didTapPeakNotification, object: status)
        }
        completionHandler()
    }

    // Show notification even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification,
                                 withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

// MARK: - Notification name

extension Notification.Name {
    static let didTapPeakNotification = Notification.Name("didTapPeakNotification")
}
