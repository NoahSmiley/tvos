import Foundation

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
