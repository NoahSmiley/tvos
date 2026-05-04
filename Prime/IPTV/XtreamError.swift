import Foundation

enum XtreamError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid Xtream API URL"
        case .invalidResponse: return "Invalid response from server"
        case .httpError(let statusCode): return "HTTP error \(statusCode)"
        case .decodingError(let error): return "Decoding error: \(error.localizedDescription)"
        }
    }
}
