import Foundation

struct JellyfinAuthResponse: Codable {
    let accessToken: String
    let user: JellyfinUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "AccessToken"
        case user = "User"
    }
}

struct JellyfinUser: Codable {
    let id: String
    let name: String

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
    }
}

struct JellyfinItemsResponse: Codable {
    let items: [JellyfinItem]
    let totalRecordCount: Int

    enum CodingKeys: String, CodingKey {
        case items = "Items"
        case totalRecordCount = "TotalRecordCount"
    }
}

struct JellyfinItem: Codable, Hashable {
    let id: String
    let name: String
    let type: String
    let seriesName: String?
    let overview: String?
    let productionYear: Int?
    let communityRating: Double?
    let officialRating: String?
    let runTimeTicks: Int64?
    let userData: JellyfinUserData?
    let imageTags: [String: String]?
    let backdropImageTags: [String]?
    let genres: [String]?
    let studios: [JellyfinNamedItem]?
    let people: [JellyfinPerson]?
    let mediaStreams: [JellyfinMediaStream]?
    let chapters: [JellyfinChapter]?
    let seasonId: String?
    let seriesId: String?
    let indexNumber: Int?
    let parentIndexNumber: Int?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case type = "Type"
        case seriesName = "SeriesName"
        case overview = "Overview"
        case productionYear = "ProductionYear"
        case communityRating = "CommunityRating"
        case officialRating = "OfficialRating"
        case runTimeTicks = "RunTimeTicks"
        case userData = "UserData"
        case imageTags = "ImageTags"
        case backdropImageTags = "BackdropImageTags"
        case genres = "Genres"
        case studios = "Studios"
        case people = "People"
        case mediaStreams = "MediaStreams"
        case chapters = "Chapters"
        case seasonId = "SeasonId"
        case seriesId = "SeriesId"
        case indexNumber = "IndexNumber"
        case parentIndexNumber = "ParentIndexNumber"
    }

    var runtimeMinutes: Int? {
        guard let ticks = runTimeTicks else { return nil }
        return Int(ticks / 600_000_000)
    }

    var primaryImageURL: URL? {
        guard let tags = imageTags, tags["Primary"] != nil else { return nil }
        return JellyfinAPI.shared.imageURL(itemId: id, imageType: "Primary")
    }

    /// For episodes, returns the series poster instead of the episode thumbnail
    var seriesPrimaryImageURL: URL? {
        guard let seriesId else { return nil }
        return JellyfinAPI.shared.imageURL(itemId: seriesId, imageType: "Primary")
    }

    /// Best poster image: series poster for episodes, own primary for everything else
    var bestPosterURL: URL? {
        if type == "Episode", let seriesURL = seriesPrimaryImageURL {
            return seriesURL
        }
        return primaryImageURL
    }

    var backdropImageURL: URL? {
        guard let tags = backdropImageTags, !tags.isEmpty else { return nil }
        return JellyfinAPI.shared.imageURL(itemId: id, imageType: "Backdrop")
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: JellyfinItem, rhs: JellyfinItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct JellyfinUserData: Codable {
    let playbackPositionTicks: Int64?
    let playCount: Int?
    let isFavorite: Bool?
    let played: Bool?
    let playedPercentage: Double?

    enum CodingKeys: String, CodingKey {
        case playbackPositionTicks = "PlaybackPositionTicks"
        case playCount = "PlayCount"
        case isFavorite = "IsFavorite"
        case played = "Played"
        case playedPercentage = "PlayedPercentage"
    }
}

struct JellyfinNamedItem: Codable {
    let name: String
    let id: String

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case id = "Id"
    }
}

struct JellyfinPerson: Codable {
    let name: String
    let id: String
    let role: String?
    let type: String?

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case id = "Id"
        case role = "Role"
        case type = "Type"
    }
}

struct JellyfinChapter: Codable {
    let startPositionTicks: Int64
    let name: String?

    enum CodingKeys: String, CodingKey {
        case startPositionTicks = "StartPositionTicks"
        case name = "Name"
    }

    var startSeconds: Double {
        Double(startPositionTicks) / 10_000_000.0
    }
}

struct JellyfinMediaStream: Codable {
    let codec: String?
    let type: String?
    let displayTitle: String?
    let language: String?

    enum CodingKeys: String, CodingKey {
        case codec = "Codec"
        case type = "Type"
        case displayTitle = "DisplayTitle"
        case language = "Language"
    }
}

struct JellyfinLibrary: Codable {
    let id: String
    let name: String
    let collectionType: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case collectionType = "CollectionType"
    }
}

struct JellyfinLibraryResponse: Codable {
    let items: [JellyfinLibrary]

    enum CodingKeys: String, CodingKey {
        case items = "Items"
    }
}

struct JellyfinPlaybackInfo: Codable {
    let mediaSources: [JellyfinMediaSource]

    enum CodingKeys: String, CodingKey {
        case mediaSources = "MediaSources"
    }
}

struct JellyfinMediaSource: Codable {
    let id: String
    let directStreamUrl: String?
    let transcodingUrl: String?
    let container: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case directStreamUrl = "DirectStreamUrl"
        case transcodingUrl = "TranscodingUrl"
        case container = "Container"
    }
}
