import Foundation

struct XtreamEPGResponse: Codable {
    let epgListings: [XtreamEPGEntry]

    enum CodingKeys: String, CodingKey {
        case epgListings = "epg_listings"
    }
}
