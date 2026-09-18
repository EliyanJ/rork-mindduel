import Foundation

/// One source for API and WebSocket version headers; no device identifier is transmitted.
nonisolated enum AppVersion {
    static var current: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0" }

    static func request(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(current, forHTTPHeaderField: "X-App-Version")
        return request
    }

    static func isOlder(_ version: String, than minimum: String) -> Bool {
        guard let lhs = components(version), let rhs = components(minimum) else { return false }
        for (a, b) in zip(lhs, rhs) where a != b { return a < b }
        return false
    }

    private static func components(_ version: String) -> [Int]? {
        let parts = version.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        let values = parts.compactMap { part -> Int? in
            guard !part.isEmpty, part.count <= 6, part.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
            return Int(part)
        }
        return values.count == 3 ? values : nil
    }
}
