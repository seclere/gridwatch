import Foundation
import CryptoKit

private enum TuyaConfig {
    static let accessID     = "9n87jh7uakj54xgsrtfh"
    static let accessSecret = "9544fc882c5449659c4711be6a6932d2"
    static let baseURL      = "https://openapi-sg.iotbing.com"
}

actor TuyaService {
    static let shared = TuyaService()

    private var accessToken: String?
    private var tokenExpiry: Date = .distantPast

    // MARK: - Public API

    func setPower(deviceID: String, on: Bool) async throws {
        print("[Tuya] setPower deviceID='\(deviceID)' on=\(on)")
        let token = try await validToken()
        let path  = "/v1.0/iot-03/devices/\(deviceID)/commands"
        let body  = CommandBody(commands: [Command(code: "switch_1", value: .bool(on))])
        let data  = try JSONEncoder().encode(body)
        let resp  = try await request(method: "POST", path: path, body: data, token: token)
        print("[Tuya] response: \(String(data: resp, encoding: .utf8) ?? "(empty)")")
    }

    /// Fetch live status: power state, wattage, and cumulative kWh.
    /// Returns (isPowered, watts, totalKwh). Nil if the plug doesn't report that value.
    func fetchStatus(deviceID: String) async throws -> (isPowered: Bool, watts: Double?, totalKwh: Double?) {
        let token    = try await validToken()
        let path     = "/v1.0/iot-03/devices/\(deviceID)/status"
        let response = try await request(method: "GET", path: path, body: nil, token: token)
        let decoded  = try JSONDecoder().decode(StatusResponse.self, from: response)

        var isPowered = false
        var watts: Double?    = nil
        var totalKwh: Double? = nil

        for item in decoded.result {
            switch item.code {
            case "switch_1", "switch":
                if case .bool(let v) = item.value { isPowered = v }
            case "cur_power":
                // 0.1W units
                if case .int(let v) = item.value         { watts = Double(v) / 10.0 }
                else if case .double(let v) = item.value { watts = v / 10.0 }
            case "add_ele", "cur_electricity":
                // 0.001 kWh units on most Tuya smart plugs
                if case .int(let v) = item.value         { totalKwh = Double(v) / 1000.0 }
                else if case .double(let v) = item.value { totalKwh = v / 1000.0 }
            default:
                break
            }
        }
        return (isPowered, watts, totalKwh)
    }

    // MARK: - Auth

    private func validToken() async throws -> String {
        if let token = accessToken, Date() < tokenExpiry { return token }
        return try await fetchToken()
    }

    private func fetchToken() async throws -> String {
        let path     = "/v1.0/token?grant_type=1"
        let response = try await request(method: "GET", path: path, body: nil, token: nil)
        print("[Tuya] token response: \(String(data: response, encoding: .utf8) ?? "(empty)")")
        let decoded  = try JSONDecoder().decode(TokenResponse.self, from: response)
        guard decoded.success, let result = decoded.result else {
            throw TuyaError.authFailed(decoded.msg ?? "Unknown error")
        }
        accessToken = result.access_token
        tokenExpiry = Date().addingTimeInterval(TimeInterval(result.expire_time - 60))
        return result.access_token
    }

    // MARK: - Signed Request

    private func request(method: String, path: String, body: Data?, token: String?) async throws -> Data {
        guard let url = URL(string: TuyaConfig.baseURL + path) else { throw TuyaError.invalidURL }
        let timestamp = String(Int(Date().timeIntervalSince1970 * 1000))
        let bodyHash  = sha256Hex(body ?? Data())
        let stringToSign = [method, bodyHash, "", path].joined(separator: "\n")
        let str: String
        var nonce: String? = nil
        if let token = token {
            let n = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
            nonce = n
            str = TuyaConfig.accessID + token + timestamp + n + stringToSign
        } else {
            str = TuyaConfig.accessID + timestamp + stringToSign
        }
        let sign = hmacSHA256Hex(key: TuyaConfig.accessSecret, data: str).uppercased()
        var req        = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(TuyaConfig.accessID, forHTTPHeaderField: "client_id")
        req.setValue(timestamp,           forHTTPHeaderField: "t")
        req.setValue(sign,                forHTTPHeaderField: "sign")
        req.setValue("HMAC-SHA256",       forHTTPHeaderField: "sign_method")
        req.setValue("en",                forHTTPHeaderField: "lang")
        if let nonce  { req.setValue(nonce, forHTTPHeaderField: "nonce") }
        if let token  { req.setValue(token, forHTTPHeaderField: "access_token") }
        if let body   { req.httpBody = body }
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw TuyaError.httpError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return data
    }

    private func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    private func hmacSHA256Hex(key: String, data: String) -> String {
        let k = SymmetricKey(data: Data(key.utf8))
        return HMAC<SHA256>.authenticationCode(for: Data(data.utf8), using: k)
            .map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Models

private struct TokenResponse: Decodable {
    let success: Bool; let msg: String?; let result: TokenResult?
    struct TokenResult: Decodable { let access_token: String; let expire_time: Int }
}
private struct CommandBody: Encodable { let commands: [Command] }
private struct Command: Encodable {
    let code: String; let value: CommandValue
    enum CommandValue: Encodable {
        case bool(Bool)
        func encode(to encoder: Encoder) throws {
            var c = encoder.singleValueContainer()
            if case .bool(let v) = self { try c.encode(v) }
        }
    }
}
private struct StatusResponse: Decodable {
    let result: [StatusItem]
    struct StatusItem: Decodable { let code: String; let value: StatusValue }
}
private enum StatusValue: Decodable {
    case bool(Bool), int(Int), double(Double), string(String)
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let v = try? c.decode(Bool.self)   { self = .bool(v);   return }
        if let v = try? c.decode(Int.self)    { self = .int(v);    return }
        if let v = try? c.decode(Double.self) { self = .double(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        self = .string("")
    }
}
enum TuyaError: Error, LocalizedError {
    case invalidURL, authFailed(String), httpError(Int), deviceNotFound
    var errorDescription: String? {
        switch self {
        case .invalidURL:          return "Invalid Tuya API URL."
        case .authFailed(let m):   return "Tuya auth failed: \(m)"
        case .httpError(let c):    return "Tuya HTTP error: \(c)"
        case .deviceNotFound:      return "Device not found."
        }
    }
}

// MARK: - Breaker (KWS-302WF) Extension
extension TuyaService {
    /// Fetch KWS-302WF status using the /properties endpoint which exposes
    /// energy DPs (101-105) that the standard /status endpoint hides.
    func fetchBreakerStatus(deviceID: String) async throws -> BreakerStatus {
        let token = try await validToken()
        // Try properties endpoint first (exposes energy DPs)
        let path = "/v1.0/iot-03/devices/\(deviceID)/properties?codes=switch,voltage,current,power,energy"
        let response = try await request(method: "GET", path: path, body: nil, token: token)
        print("[Tuya:breaker] response: \(String(data: response, encoding: .utf8) ?? "(empty)")")

        var status = BreakerStatus()
        status.lastUpdated = Date()

        if let decoded = try? JSONDecoder().decode(PropertiesResponse.self, from: response),
           decoded.success {
            for prop in decoded.result.properties {
                switch prop.code {
                case "switch":
                    if case .bool(let v) = prop.value { status.isOn = v }
                case "voltage":
                    if case .int(let v) = prop.value    { status.voltage = Double(v) / 10.0 }
                    else if case .double(let v) = prop.value { status.voltage = v / 10.0 }
                case "current":
                    if case .int(let v) = prop.value    { status.current = Double(v) }
                    else if case .double(let v) = prop.value { status.current = v }
                case "power":
                    if case .int(let v) = prop.value    { status.currentWatts = Double(v) / 10.0 }
                    else if case .double(let v) = prop.value { status.currentWatts = v / 10.0 }
                case "energy":
                    // DP 105: cumulative kWh in units of 0.01 kWh
                    if case .int(let v) = prop.value    { status.totalKwh = Double(v) / 100.0 }
                    else if case .double(let v) = prop.value { status.totalKwh = v / 100.0 }
                default: break
                }
            }
        } else {
            // Fallback: try raw DPS numeric codes
            let fallbackPath = "/v1.0/iot-03/devices/\(deviceID)/status"
            let fallback = try await request(method: "GET", path: fallbackPath, body: nil, token: token)
            if let decoded = try? JSONDecoder().decode(StatusResponse.self, from: fallback) {
                for item in decoded.result {
                    switch item.code {
                    case "switch_1", "switch":
                        if case .bool(let v) = item.value { status.isOn = v }
                    case "cur_power", "power":
                        if case .int(let v) = item.value    { status.currentWatts = Double(v) / 10.0 }
                        else if case .double(let v) = item.value { status.currentWatts = v / 10.0 }
                    case "add_ele", "energy", "cur_electricity":
                        if case .int(let v) = item.value    { status.totalKwh = Double(v) / 100.0 }
                        else if case .double(let v) = item.value { status.totalKwh = v / 100.0 }
                    default: break
                    }
                }
            }
        }
        return status
    }
}

// Properties response model
private struct PropertiesResponse: Decodable {
    let success: Bool
    let result: PropertiesResult
    struct PropertiesResult: Decodable {
        let properties: [PropertyItem]
    }
    struct PropertyItem: Decodable {
        let code: String
        let value: StatusValue
    }
}
