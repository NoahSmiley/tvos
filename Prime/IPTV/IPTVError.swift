import Foundation

enum IPTVError: LocalizedError {
    case noPlaylistConfigured
    case downloadFailed
    case parseError

    var errorDescription: String? {
        switch self {
        case .noPlaylistConfigured: return "No IPTV playlist URL configured"
        case .downloadFailed: return "Failed to download playlist"
        case .parseError: return "Failed to parse playlist"
        }
    }
}
