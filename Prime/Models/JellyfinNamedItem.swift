import Foundation

struct JellyfinNamedItem: Codable {
    let name: String
    let id: String

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case id = "Id"
    }
}
