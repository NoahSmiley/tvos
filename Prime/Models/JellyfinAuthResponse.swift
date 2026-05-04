import Foundation

struct JellyfinAuthResponse: Codable {
    let accessToken: String
    let user: JellyfinUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "AccessToken"
        case user = "User"
    }
}
