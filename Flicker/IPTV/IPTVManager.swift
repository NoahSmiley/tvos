import Foundation

final class IPTVManager {

    static let shared = IPTVManager()

    private(set) var channels: [IPTVChannel] = []
    private(set) var groups: [IPTVGroup] = []

    private let playlistURLKey = "iptvPlaylistURL"

    var playlistURL: URL? {
        get {
            guard let str = UserDefaults.standard.string(forKey: playlistURLKey) else { return nil }
            return URL(string: str)
        }
        set {
            UserDefaults.standard.set(newValue?.absoluteString, forKey: playlistURLKey)
        }
    }

    private init() {}

    // MARK: - Load

    func loadPlaylist() async throws {
        guard let url = playlistURL else {
            throw IPTVError.noPlaylistConfigured
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw IPTVError.downloadFailed
        }

        let parsed = M3UParser.parse(data: data)
        guard !parsed.isEmpty else {
            throw IPTVError.parseError
        }

        channels = parsed
        buildGroups()
    }

    func loadFromString(_ content: String) {
        channels = M3UParser.parse(content: content)
        buildGroups()
    }

    private func buildGroups() {
        var grouped: [String: [IPTVChannel]] = [:]
        for channel in channels {
            grouped[channel.group, default: []].append(channel)
        }
        groups = grouped
            .sorted { $0.key < $1.key }
            .map { IPTVGroup(name: $0.key, channels: $0.value) }
    }

    // MARK: - Search

    func search(query: String) -> [IPTVChannel] {
        let lowered = query.lowercased()
        return channels.filter { $0.name.lowercased().contains(lowered) }
    }
}

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
