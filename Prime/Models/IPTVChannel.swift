import Foundation

struct IPTVChannel: Hashable {
    let id: String
    let name: String
    let group: String
    let logoURL: URL?
    let streamURL: URL

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: IPTVChannel, rhs: IPTVChannel) -> Bool {
        lhs.id == rhs.id
    }
}
