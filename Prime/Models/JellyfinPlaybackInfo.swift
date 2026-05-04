import Foundation

struct JellyfinPlaybackInfo: Codable {
    let mediaSources: [JellyfinMediaSource]

    enum CodingKeys: String, CodingKey {
        case mediaSources = "MediaSources"
    }
}
