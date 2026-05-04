import Foundation

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
