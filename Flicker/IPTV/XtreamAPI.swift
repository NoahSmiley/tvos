import Foundation

// MARK: - Data Models

struct XtreamCategory: Codable, Identifiable {
    let categoryId: String
    let categoryName: String
    let parentId: Int

    var id: String { categoryId }

    enum CodingKeys: String, CodingKey {
        case categoryId = "category_id"
        case categoryName = "category_name"
        case parentId = "parent_id"
    }
}

struct XtreamStream: Codable, Identifiable {
    let num: Int
    let name: String
    let streamType: String
    let streamId: Int
    let streamIcon: String?
    let epgChannelId: String?
    let categoryId: String?
    let tvArchive: Int

    var id: Int { streamId }

    enum CodingKeys: String, CodingKey {
        case num, name
        case streamType = "stream_type"
        case streamId = "stream_id"
        case streamIcon = "stream_icon"
        case epgChannelId = "epg_channel_id"
        case categoryId = "category_id"
        case tvArchive = "tv_archive"
    }
}

struct XtreamEPGEntry: Codable {
    let id: String
    let title: String
    let start: String
    let end: String
    let description: String
    let channelId: String
    let streamId: String

    enum CodingKeys: String, CodingKey {
        case id, title, start, end, description
        case channelId = "channel_id"
        case streamId = "stream_id"
    }

    var decodedTitle: String {
        guard let data = Data(base64Encoded: title),
              let str = String(data: data, encoding: .utf8) else { return title }
        return str
    }

    var decodedDescription: String {
        guard let data = Data(base64Encoded: description),
              let str = String(data: data, encoding: .utf8) else { return description }
        return str
    }

    var minutesRemaining: Int? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        guard let endDate = formatter.date(from: end) else { return nil }
        let remaining = endDate.timeIntervalSince(Date())
        guard remaining > 0 else { return nil }
        return Int(remaining / 60)
    }
}

struct XtreamEPGResponse: Codable {
    let epgListings: [XtreamEPGEntry]

    enum CodingKeys: String, CodingKey {
        case epgListings = "epg_listings"
    }
}

// MARK: - Error

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

// MARK: - API Client

final class XtreamAPI {
    static let shared = XtreamAPI()

    private let session: URLSession
    private let decoder = JSONDecoder()

    private let baseURL = "http://line.trxdnscloud.ru"
    private let username = "914f80594b"
    private let password = "32d6ec5d6f"

    // EPG cache: streamId -> (entries, fetchTime)
    private var epgCache: [Int: (entries: [XtreamEPGEntry], fetched: Date)] = [:]
    private let epgCacheDuration: TimeInterval = 300 // 5 minutes

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 300
        session = URLSession(configuration: config)
    }

    // MARK: - URL Building

    private func apiURL(action: String? = nil, extraParams: [URLQueryItem] = []) -> URL? {
        var components = URLComponents(string: baseURL)
        components?.path = "/player_api.php"

        var queryItems = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password)
        ]

        if let action {
            queryItems.append(URLQueryItem(name: "action", value: action))
        }

        queryItems.append(contentsOf: extraParams)
        components?.queryItems = queryItems

        return components?.url
    }

    // MARK: - Generic Request

    private func request<T: Decodable>(_ url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw XtreamError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw XtreamError.httpError(statusCode: httpResponse.statusCode)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw XtreamError.decodingError(error)
        }
    }

    // MARK: - Categories

    func getCategories() async throws -> [XtreamCategory] {
        guard let url = apiURL(action: "get_live_categories") else {
            throw XtreamError.invalidURL
        }
        return try await request(url)
    }

    // MARK: - Live Streams

    func getLiveStreams(categoryId: String? = nil) async throws -> [XtreamStream] {
        var extraParams: [URLQueryItem] = []
        if let categoryId {
            extraParams.append(URLQueryItem(name: "category_id", value: categoryId))
        }

        guard let url = apiURL(action: "get_live_streams", extraParams: extraParams) else {
            throw XtreamError.invalidURL
        }
        return try await request(url)
    }

    // MARK: - EPG

    func getEPG(streamId: Int) async throws -> [XtreamEPGEntry] {
        let extraParams = [URLQueryItem(name: "stream_id", value: "\(streamId)")]

        guard let url = apiURL(action: "get_short_epg", extraParams: extraParams) else {
            throw XtreamError.invalidURL
        }

        let response: XtreamEPGResponse = try await request(url)
        return response.epgListings
    }

    /// Gets EPG with caching
    func getCachedEPG(streamId: Int) async -> [XtreamEPGEntry] {
        // Check cache
        if let cached = epgCache[streamId], Date().timeIntervalSince(cached.fetched) < epgCacheDuration {
            return cached.entries
        }

        do {
            let entries = try await getEPG(streamId: streamId)
            epgCache[streamId] = (entries, Date())
            return entries
        } catch {
            return []
        }
    }

    /// Gets the currently airing program for a stream
    func getCurrentProgram(streamId: Int) async -> XtreamEPGEntry? {
        let entries = await getCachedEPG(streamId: streamId)
        let now = Date()

        return entries.first { entry in
            guard let start = Self.epgDateFormatter.date(from: entry.start),
                  let end = Self.epgDateFormatter.date(from: entry.end) else { return false }
            return now >= start && now < end
        }
    }

    /// EPG timestamps are in UTC
    private static let epgDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    // MARK: - Stream URL

    func streamURL(for streamId: Int) -> URL? {
        var components = URLComponents(string: baseURL)
        components?.path = "/live/\(username)/\(password)/\(streamId).m3u8"
        return components?.url
    }
}
