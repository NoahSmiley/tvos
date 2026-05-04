import Foundation

enum JellyfinError: LocalizedError {
    case notConfigured
    case authenticationFailed
    case unauthorized
    case networkError
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Server not configured"
        case .authenticationFailed: return "Authentication failed"
        case .unauthorized: return "Session expired"
        case .networkError: return "Network error"
        case .serverError(let code): return "Server error (\(code))"
        }
    }
}
