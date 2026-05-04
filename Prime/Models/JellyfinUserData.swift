import Foundation

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
