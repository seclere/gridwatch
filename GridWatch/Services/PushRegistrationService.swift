//
//  PushRegistrationService.swift
//  GridWatch
//
//  Created by Ysrael Salces on 5/13/26.
//


import UIKit

struct PushRegistrationService {

    static let registrationEndpoint = URL(string:
        "https://code-number-api--estialesti.replit.app/api/register-device"
    )!

    /// Call this after APNs gives you a device token.
    /// Converts the raw token Data to a hex string and POSTs it to Replit.
    static func registerToken(_ tokenData: Data) async {
        let token = tokenData.map { String(format: "%02x", $0) }.joined()
        print("[Push] registering device token: \(token.prefix(16))...")

        var req = URLRequest(url: registrationEndpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(["deviceToken": token])

        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse {
                print("[Push] registration response: \(http.statusCode)")
            }
        } catch {
            print("[Push] registration failed: \(error)")
        }
    }
}
