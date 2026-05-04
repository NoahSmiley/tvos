import Foundation

final class JellyfinAPI {

    static let shared = JellyfinAPI()

    private(set) var serverURL: URL? = URL(string: "https://jellyfin.athion.me")
    private(set) var accessToken: String?
    private(set) var userId: String?

    private let hardcodedUsername = "noah"
    private let hardcodedPassword = ""

    private let deviceId: String
    private let deviceName = "Prime tvOS"
    private let clientName = "Athion Prime"
    private let clientVersion = "1.0.0"

    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        deviceId = UserDefaults.standard.string(forKey: "flickerDeviceId") ?? {
            let id = UUID().uuidString
            UserDefaults.standard.set(id, forKey: "flickerDeviceId")
            return id
        }()

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 300
        session = URLSession(configuration: config)
        decoder = JSONDecoder()

        // Restore saved session
        accessToken = UserDefaults.standard.string(forKey: "flickerAccessToken")
        userId = UserDefaults.standard.string(forKey: "flickerUserId")
    }

    var isAuthenticated: Bool {
        serverURL != nil && accessToken != nil && userId != nil
    }

    /// Auto-login on launch using hardcoded credentials
    func autoLogin() async {
        // Always re-authenticate to ensure a valid token
        accessToken = nil
        userId = nil

        do {
            let user = try await authenticate(username: hardcodedUsername, password: hardcodedPassword)
            print("[Jellyfin] Auto-login succeeded as \(user.name), userId=\(userId ?? "nil")")
        } catch {
            print("[Jellyfin] Auto-login failed: \(error)")
        }
    }

    // MARK: - Auth Header

    private var authHeader: String {
        var header = "MediaBrowser Client=\"\(clientName)\", Device=\"\(deviceName)\", DeviceId=\"\(deviceId)\", Version=\"\(clientVersion)\""
        if let token = accessToken {
            header += ", Token=\"\(token)\""
        }
        return header
    }

    // MARK: - URL Building

    private func buildURL(path: String) -> URL? {
        guard let serverURL else { return nil }
        // Strip leading slash to avoid double-slash
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return serverURL.appendingPathComponent(cleanPath)
    }

    // MARK: - Authenticate

    func authenticate(username: String, password: String) async throws -> JellyfinUser {
        guard let url = buildURL(path: "Users/AuthenticateByName") else {
            throw JellyfinError.notConfigured
        }

        print("[Jellyfin] POST \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authHeader, forHTTPHeaderField: "X-Emby-Authorization")

        let body: [String: String] = ["Username": username, "Pw": password]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw JellyfinError.networkError
        }

        print("[Jellyfin] Auth response: \(http.statusCode)")

        guard http.statusCode == 200 else {
            throw JellyfinError.authenticationFailed
        }

        let authResponse = try decoder.decode(JellyfinAuthResponse.self, from: data)
        accessToken = authResponse.accessToken
        userId = authResponse.user.id

        UserDefaults.standard.set(accessToken, forKey: "flickerAccessToken")
        UserDefaults.standard.set(userId, forKey: "flickerUserId")

        return authResponse.user
    }

    func logout() {
        accessToken = nil
        userId = nil
        UserDefaults.standard.removeObject(forKey: "flickerAccessToken")
        UserDefaults.standard.removeObject(forKey: "flickerUserId")
    }

    // MARK: - Libraries

    func getLibraries() async throws -> [JellyfinLibrary] {
        guard let userId else { throw JellyfinError.notConfigured }
        let data = try await get(path: "Users/\(userId)/Views")
        let response = try decoder.decode(JellyfinLibraryResponse.self, from: data)
        return response.items
    }

    // MARK: - Items

    func getLatestItems(parentId: String? = nil, limit: Int = 16) async throws -> [JellyfinItem] {
        guard let userId else { throw JellyfinError.notConfigured }
        var params: [String: String] = [
            "Limit": "\(limit)",
            "Fields": "Overview,Genres,Studios,People,MediaStreams,Chapters",
            "EnableImageTypes": "Primary,Backdrop",
            "ImageTypeLimit": "1"
        ]
        if let parentId { params["ParentId"] = parentId }

        let data = try await get(path: "Users/\(userId)/Items/Latest", queryItems: params)
        return try decoder.decode([JellyfinItem].self, from: data)
    }

    func getResumeItems(limit: Int = 12) async throws -> [JellyfinItem] {
        guard let userId else { throw JellyfinError.notConfigured }
        let params: [String: String] = [
            "Limit": "\(limit)",
            "Fields": "Overview,Genres,MediaStreams",
            "EnableImageTypes": "Primary,Backdrop",
            "MediaTypes": "Video"
        ]
        let data = try await get(path: "Users/\(userId)/Items/Resume", queryItems: params)
        let response = try decoder.decode(JellyfinItemsResponse.self, from: data)
        return response.items
    }

    func getItems(
        parentId: String? = nil,
        includeItemTypes: String? = nil,
        sortBy: String = "SortName",
        sortOrder: String = "Ascending",
        startIndex: Int = 0,
        limit: Int = 50,
        searchTerm: String? = nil,
        genres: String? = nil
    ) async throws -> JellyfinItemsResponse {
        guard let userId else { throw JellyfinError.notConfigured }
        var params: [String: String] = [
            "SortBy": sortBy,
            "SortOrder": sortOrder,
            "StartIndex": "\(startIndex)",
            "Limit": "\(limit)",
            "Recursive": "true",
            "Fields": "Overview,Genres,Studios,People,MediaStreams,Chapters",
            "EnableImageTypes": "Primary,Backdrop",
            "ImageTypeLimit": "1"
        ]
        if let parentId { params["ParentId"] = parentId }
        if let types = includeItemTypes { params["IncludeItemTypes"] = types }
        if let term = searchTerm { params["SearchTerm"] = term }
        if let genres { params["Genres"] = genres }

        let data = try await get(path: "Users/\(userId)/Items", queryItems: params)
        return try decoder.decode(JellyfinItemsResponse.self, from: data)
    }

    func getItem(id: String) async throws -> JellyfinItem {
        guard let userId else { throw JellyfinError.notConfigured }
        let data = try await get(
            path: "Users/\(userId)/Items/\(id)",
            queryItems: ["Fields": "Overview,Genres,Studios,People,MediaStreams,Chapters"]
        )
        return try decoder.decode(JellyfinItem.self, from: data)
    }

    func getSeasons(seriesId: String) async throws -> [JellyfinItem] {
        guard let userId else { throw JellyfinError.notConfigured }
        let data = try await get(path: "Shows/\(seriesId)/Seasons", queryItems: ["UserId": userId])
        let response = try decoder.decode(JellyfinItemsResponse.self, from: data)
        return response.items
    }

    func getEpisodes(seriesId: String, seasonId: String) async throws -> [JellyfinItem] {
        guard let userId else { throw JellyfinError.notConfigured }
        let params: [String: String] = [
            "UserId": userId,
            "SeasonId": seasonId,
            "Fields": "Overview,MediaStreams,Chapters"
        ]
        let data = try await get(path: "Shows/\(seriesId)/Episodes", queryItems: params)
        let response = try decoder.decode(JellyfinItemsResponse.self, from: data)
        return response.items
    }

    // MARK: - Playback

    // Local Jellyfin URL for streaming (bypasses Cloudflare tunnel for 4K)
    private var streamBaseURL: URL? {
        // Use local network when on the same LAN — much faster for 4K
        if let local = URL(string: "http://192.168.0.159:8096"),
           serverURL?.host?.contains("athion.me") == true {
            return local
        }
        return serverURL
    }

    /// HLS remux/transcode — adapts quality based on network.
    /// Local: full 4K remux (no re-encoding). Remote: respects quality setting.
    func getHLSRemuxURL(itemId: String) -> URL? {
        guard let token = accessToken, let base = streamBaseURL else { return nil }

        let isLocal = base.host?.contains("192.168") == true || base.host == "localhost"
        let quality = RemoteStreamQuality.current

        // Local = always full quality. Remote = use quality setting.
        let bitrate = isLocal ? 200_000_000 : quality.maxBitrate

        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        components?.path = "/Videos/\(itemId)/master.m3u8"
        var queryItems = [
            URLQueryItem(name: "MediaSourceId", value: itemId),
            URLQueryItem(name: "VideoCodec", value: "hevc,h264"),
            URLQueryItem(name: "AudioCodec", value: "eac3,ac3,aac"),
            URLQueryItem(name: "Container", value: "mp4,ts"),
            URLQueryItem(name: "SegmentContainer", value: "mp4"),
            URLQueryItem(name: "SegmentLength", value: "6"),
            URLQueryItem(name: "TranscodingMaxAudioChannels", value: "8"),
            URLQueryItem(name: "MaxStreamingBitrate", value: "\(bitrate)"),
            URLQueryItem(name: "VideoBitrate", value: "\(bitrate)"),
            URLQueryItem(name: "SubtitleMethod", value: "Hls"),
            URLQueryItem(name: "api_key", value: token)
        ]

        // For remote with lower quality, add max width to trigger transcode
        if !isLocal, let maxWidth = quality.maxWidth {
            queryItems.append(URLQueryItem(name: "MaxWidth", value: "\(maxWidth)"))
        }

        components?.queryItems = queryItems
        return components?.url
    }

    /// Returns the best playback URL. Local = full 4K remux. Remote = adaptive quality.
    func playbackURL(itemId: String) -> URL? {
        return getHLSRemuxURL(itemId: itemId)
    }

    // Alias for backward compat
    func getTranscodeURL(itemId: String) -> URL? {
        return getHLSRemuxURL(itemId: itemId)
    }

    func reportPlaybackStart(itemId: String, positionTicks: Int64 = 0) async {
        let body: [String: Any] = ["ItemId": itemId, "PositionTicks": positionTicks]
        try? await post(path: "Sessions/Playing", body: body)
    }

    func reportPlaybackProgress(itemId: String, positionTicks: Int64, isPaused: Bool) async {
        let body: [String: Any] = ["ItemId": itemId, "PositionTicks": positionTicks, "IsPaused": isPaused]
        try? await post(path: "Sessions/Playing/Progress", body: body)
    }

    func reportPlaybackStopped(itemId: String, positionTicks: Int64) async {
        let body: [String: Any] = ["ItemId": itemId, "PositionTicks": positionTicks]
        try? await post(path: "Sessions/Playing/Stopped", body: body)
    }

    // MARK: - Images

    func imageURL(itemId: String, imageType: String, maxWidth: Int = 600) -> URL? {
        guard let base = buildURL(path: "Items/\(itemId)/Images/\(imageType)") else { return nil }
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "maxWidth", value: "\(maxWidth)"),
            URLQueryItem(name: "quality", value: "90")
        ]
        return components?.url
    }

    // MARK: - Networking

    private func get(path: String, queryItems: [String: String]? = nil) async throws -> Data {
        guard let base = buildURL(path: path) else { throw JellyfinError.notConfigured }

        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        if let queryItems {
            components.queryItems = queryItems.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        var request = URLRequest(url: components.url!)
        request.setValue(authHeader, forHTTPHeaderField: "X-Emby-Authorization")

        print("[Jellyfin] GET \(components.url!.absoluteString)")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw JellyfinError.networkError }

        print("[Jellyfin] -> \(http.statusCode) (\(data.count) bytes)")

        if http.statusCode == 401 { throw JellyfinError.unauthorized }
        guard (200...299).contains(http.statusCode) else {
            throw JellyfinError.serverError(http.statusCode)
        }

        return data
    }

    private func post(path: String, body: [String: Any]) async throws {
        guard let url = buildURL(path: path) else { throw JellyfinError.notConfigured }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authHeader, forHTTPHeaderField: "X-Emby-Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw JellyfinError.networkError
        }
    }
}

// MARK: - Errors

