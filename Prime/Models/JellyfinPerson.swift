import Foundation

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
