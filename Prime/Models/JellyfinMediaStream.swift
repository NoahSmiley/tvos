import Foundation

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
