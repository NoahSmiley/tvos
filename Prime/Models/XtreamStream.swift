import Foundation

struct XtreamStream: Codable, Identifiable {
    let num: Int
    let name: String
    let streamType: String
    let streamId: Int
    let streamIcon: String?
    let epgChannelId: String?
    let categoryId: String?
    let tvArchive: Int

    var id: Int { streamId }

    enum CodingKeys: String, CodingKey {
        case num, name
        case streamType = "stream_type"
        case streamId = "stream_id"
        case streamIcon = "stream_icon"
        case epgChannelId = "epg_channel_id"
        case categoryId = "category_id"
        case tvArchive = "tv_archive"
    }
}
