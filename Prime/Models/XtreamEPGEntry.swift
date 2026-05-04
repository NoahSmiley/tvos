import Foundation

struct XtreamEPGEntry: Codable {
    let id: String
    let title: String
    let start: String
    let end: String
    let description: String
    let channelId: String?
    let streamId: String?

    enum CodingKeys: String, CodingKey {
        case id, title, start, end, description
        case channelId = "channel_id"
        case streamId = "stream_id"
    }

    var decodedTitle: String {
        guard let data = Data(base64Encoded: title),
              let str = String(data: data, encoding: .utf8) else { return title }
        return str
    }

    var decodedDescription: String {
        guard let data = Data(base64Encoded: description),
              let str = String(data: data, encoding: .utf8) else { return description }
        return str
    }

    var minutesRemaining: Int? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        guard let endDate = formatter.date(from: end) else { return nil }
        let remaining = endDate.timeIntervalSince(Date())
        guard remaining > 0 else { return nil }
        return Int(remaining / 60)
    }
}
