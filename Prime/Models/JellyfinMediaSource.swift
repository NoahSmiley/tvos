import Foundation

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
