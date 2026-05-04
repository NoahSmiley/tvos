import Foundation

enum RemoteStreamQuality: Int, CaseIterable {
    case maximum = 0     // Full quality remux (local only, will buffer remote)
    case high = 1        // 1080p 20 Mbps
    case medium = 2      // 1080p 8 Mbps
    case low = 3         // 720p 4 Mbps

    var title: String {
        switch self {
        case .maximum: return "Maximum (Original)"
        case .high: return "High (1080p 20 Mbps)"
        case .medium: return "Medium (1080p 8 Mbps)"
        case .low: return "Low (720p 4 Mbps)"
        }
    }

    var subtitle: String {
        switch self {
        case .maximum: return "Full 4K Blu-ray. May buffer on slow connections."
        case .high: return "Great quality. Works on most connections."
        case .medium: return "Good quality. Reliable streaming."
        case .low: return "Lower quality. Best for slow connections."
        }
    }

    /// Max bitrate in bits per second
    var maxBitrate: Int {
        switch self {
        case .maximum: return 200_000_000
        case .high: return 20_000_000
        case .medium: return 8_000_000
        case .low: return 4_000_000
        }
    }

    /// Max video width for transcoding
    var maxWidth: Int? {
        switch self {
        case .maximum: return nil
        case .high: return 1920
        case .medium: return 1920
        case .low: return 1280
        }
    }

    static var current: RemoteStreamQuality {
        RemoteStreamQuality(rawValue: UserDefaults.standard.integer(forKey: "flickerRemoteQuality")) ?? .high
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: "flickerRemoteQuality")
    }
}

