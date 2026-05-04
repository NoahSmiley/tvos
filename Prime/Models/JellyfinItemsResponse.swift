import Foundation

struct JellyfinItemsResponse: Codable {
    let items: [JellyfinItem]
    let totalRecordCount: Int

    enum CodingKeys: String, CodingKey {
        case items = "Items"
        case totalRecordCount = "TotalRecordCount"
    }
}
