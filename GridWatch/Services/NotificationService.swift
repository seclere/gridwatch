//
//  NotificationService.swift
//  GridWatch
//
//  Created by Ysrael Salces on 5/1/26.
//

import UserNotifications

actor NotificationService {
    static let shared = NotificationService()

    // Call once at launch to request permission
    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func sendPeakShiftNotification(to status: PeakStatus, price: Double) async {
        let content = UNMutableNotificationContent()

        switch status {
        case .onPeak:
            content.title  = "⚡ On-Peak Period Started"
            content.body   = String(format: "Current price: ₱%.3f/kWh. Open GridWatch to switch off non-essential loads.", price)
            content.sound  = .defaultCritical
        case .offPeak:
            content.title  = "✅ Off-Peak Period Started"
            content.body   = String(format: "Current price: ₱%.3f/kWh. Open GridWatch to restore your sockets.", price)
            content.sound  = .default
        }

        content.userInfo = ["peakStatus": status == .onPeak ? "onPeak" : "offPeak"]
        content.categoryIdentifier = "PEAK_SHIFT"

        let request = UNNotificationRequest(
            identifier: "peak-shift-\(UUID().uuidString)",
            content: content,
            trigger: nil   // deliver immediately
        )

        try? await UNUserNotificationCenter.current().add(request)
    }
}
