import Foundation

struct JellyfinLibraryResponse: Codable {
    let items: [JellyfinLibrary]

    enum CodingKeys: String, CodingKey {
        case items = "Items"
    }
}
