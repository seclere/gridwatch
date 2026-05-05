import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingFailed(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:          return "Invalid API URL."
        case .invalidResponse:     return "Unexpected response from server."
        case .decodingFailed(let raw): return "Could not parse price from: \"\(raw)\""
        case .networkError(let e): return e.localizedDescription
        }
    }
}

actor WESMService {
    static let shared = WESMService()

    private let endpoint = URL(string:
        "https://fca56e6b-9cee-4c14-b6da-8b099f224303-00-1hvq6fpq2mbky.spock.replit.dev/api/luzon-price"
    )!

    /// Fetches the current Luzon LMP.
    /// The API returns a plain integer string (e.g. "4296") representing ₱/MWh.
    func fetchCurrentPrice() async throws -> WESMPrice {
        let (data, response) = try await URLSession.shared.data(from: endpoint)

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw APIError.invalidResponse
        }

        guard
            let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
            let value = Int(raw)
        else {
            let raw = String(data: data, encoding: .utf8) ?? "(empty)"
            throw APIError.decodingFailed(raw)
        }

        return WESMPrice(rawMWh: value)
    }
}
