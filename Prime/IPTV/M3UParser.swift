import Foundation

final class M3UParser {

    static func parse(data: Data) -> [IPTVChannel] {
        guard let content = String(data: data, encoding: .utf8) else { return [] }
        return parse(content: content)
    }

    static func parse(content: String) -> [IPTVChannel] {
        let lines = content.components(separatedBy: .newlines)
        var channels: [IPTVChannel] = []

        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("#EXTINF:") {
                let name = extractName(from: line)
                let group = extractAttribute(key: "group-title", from: line) ?? "Uncategorized"
                let logoString = extractAttribute(key: "tvg-logo", from: line)
                let tvgId = extractAttribute(key: "tvg-id", from: line) ?? UUID().uuidString

                // Next non-empty, non-comment line should be the URL
                i += 1
                while i < lines.count {
                    let urlLine = lines[i].trimmingCharacters(in: .whitespaces)
                    if !urlLine.isEmpty && !urlLine.hasPrefix("#") {
                        if let streamURL = URL(string: urlLine) {
                            let channel = IPTVChannel(
                                id: tvgId,
                                name: name,
                                group: group,
                                logoURL: logoString.flatMap { URL(string: $0) },
                                streamURL: streamURL
                            )
                            channels.append(channel)
                        }
                        break
                    }
                    i += 1
                }
            }
            i += 1
        }

        return channels
    }

    private static func extractName(from line: String) -> String {
        // Name is everything after the last comma in the EXTINF line
        guard let commaRange = line.range(of: ",", options: .backwards) else {
            return "Unknown Channel"
        }
        let name = String(line[commaRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Unknown Channel" : name
    }

    private static func extractAttribute(key: String, from line: String) -> String? {
        let pattern = "\(key)=\"([^\"]*)\""
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line) else {
            return nil
        }
        let value = String(line[range])
        return value.isEmpty ? nil : value
    }
}
