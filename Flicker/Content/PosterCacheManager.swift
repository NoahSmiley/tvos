import UIKit

/// Manages the local poster cache, matching Jellyfin items to alternate poster images
/// stored at ~/Downloads/cache/18a31b5ccc30893c/[Title]/covers/
final class PosterCacheManager {

    static let shared = PosterCacheManager()

    /// Base path for the poster cache on the Mac dev machine.
    /// On tvOS this will be bundled or served — for now, load from bundle resource.
    private let cacheBasePath: String

    /// itemId -> selected poster index (persisted)
    private var selections: [String: Int] = [:]

    /// Normalized title -> covers path mapping (built once at init)
    /// Includes both collection-level and individual movie entries
    private var folderIndex: [String: String] = [:]

    /// covers path -> list of cover file paths
    private var coverFiles: [String: [String]] = [:]

    private let defaults = UserDefaults.standard
    private let selectionsKey = "flickerPosterSelections"

    private init() {
        // Look for poster cache bundled into the app
        if let bundlePath = Bundle.main.resourcePath {
            cacheBasePath = (bundlePath as NSString).appendingPathComponent("PosterCache")
        } else {
            cacheBasePath = ""
        }

        selections = defaults.dictionary(forKey: selectionsKey) as? [String: Int] ?? [:]
        buildIndex()
    }

    private func buildIndex() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: cacheBasePath) else {
            print("[PosterCache] Cache not found at \(cacheBasePath)")
            return
        }

        guard let topFolders = try? fm.contentsOfDirectory(atPath: cacheBasePath) else { return }

        for folder in topFolders {
            let folderPath = (cacheBasePath as NSString).appendingPathComponent(folder)

            // Index the top-level folder's own covers (collection poster)
            indexCovers(at: folderPath, name: folder)

            // Scan for sub-folders (individual movies inside a collection)
            guard let subFolders = try? fm.contentsOfDirectory(atPath: folderPath) else { continue }
            for sub in subFolders {
                guard sub != "covers" else { continue }
                let subPath = (folderPath as NSString).appendingPathComponent(sub)
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: subPath, isDirectory: &isDir), isDir.boolValue else { continue }
                indexCovers(at: subPath, name: sub)
            }
        }

        print("[PosterCache] Indexed \(coverFiles.count) titles with custom posters")
    }

    private func indexCovers(at folderPath: String, name: String) {
        let coversPath = (folderPath as NSString).appendingPathComponent("covers")
        let fm = FileManager.default

        guard let files = try? fm.contentsOfDirectory(atPath: coversPath) else { return }

        let imageFiles = files.filter { file in
            let ext = (file as NSString).pathExtension.lowercased()
            return ["jpg", "jpeg", "png", "webp"].contains(ext)
        }.sorted()

        guard !imageFiles.isEmpty else { return }

        let fullPaths = imageFiles.map { (coversPath as NSString).appendingPathComponent($0) }
        // Use the covers path as key (unique per folder)
        coverFiles[coversPath] = fullPaths

        let normalized = Self.normalize(name)
        // Individual movies override collection-level entries
        folderIndex[normalized] = coversPath
    }

    // MARK: - Public API

    /// Returns alternate poster images for a Jellyfin item, or nil if none exist
    func posterPaths(for item: JellyfinItem) -> [String]? {
        guard let coversPath = matchFolder(for: item) else { return nil }
        return coverFiles[coversPath]
    }

    /// Returns the currently selected custom poster image for an item, or nil
    func selectedPoster(for item: JellyfinItem) -> UIImage? {
        guard let paths = posterPaths(for: item), !paths.isEmpty else { return nil }
        let index = selections[item.id] ?? 0
        let safePath = paths[index % paths.count]
        return UIImage(contentsOfFile: safePath)
    }

    /// Returns the selected poster index for an item
    func selectedIndex(for itemId: String) -> Int? {
        return selections[itemId]
    }

    /// Cycles to the next poster and returns it
    func cycleToNext(for item: JellyfinItem) -> UIImage? {
        guard let paths = posterPaths(for: item), paths.count > 1 else { return nil }
        let current = selections[item.id] ?? 0
        let next = (current + 1) % paths.count
        selections[item.id] = next
        defaults.set(selections, forKey: selectionsKey)
        return UIImage(contentsOfFile: paths[next])
    }

    /// Selects a specific poster index
    func selectPoster(at index: Int, for item: JellyfinItem) {
        selections[item.id] = index
        defaults.set(selections, forKey: selectionsKey)
    }

    /// Clears custom poster selection (reverts to Jellyfin poster)
    func clearSelection(for item: JellyfinItem) {
        selections.removeValue(forKey: item.id)
        defaults.set(selections, forKey: selectionsKey)
    }

    /// Returns true if this item has custom posters available
    func hasCustomPosters(for item: JellyfinItem) -> Bool {
        return matchFolder(for: item) != nil
    }

    /// Returns the count of available posters for an item
    func posterCount(for item: JellyfinItem) -> Int {
        return posterPaths(for: item)?.count ?? 0
    }

    /// Loads all poster thumbnails for the picker
    func loadPosterThumbnails(for item: JellyfinItem) -> [UIImage] {
        guard let paths = posterPaths(for: item) else { return [] }
        return paths.compactMap { path in
            guard let image = UIImage(contentsOfFile: path) else { return nil }
            // Downscale for picker thumbnails
            let targetSize = CGSize(width: 200, height: 300)
            UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: targetSize))
            let thumb = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return thumb
        }
    }

    // MARK: - Matching

    private func matchFolder(for item: JellyfinItem) -> String? {
        let name = item.name
        let isCollection = item.type == "BoxSet"
        let normalized = Self.normalize(name)

        // 1. Exact match on item name
        if let path = folderIndex[normalized] {
            return path
        }

        // 2. Strip "collection" suffix (e.g. "Harry Potter Collection" -> "harry potter")
        let withoutCollection = normalized
            .replacingOccurrences(of: "\\s*collection$", with: "", options: .regularExpression)
        if withoutCollection != normalized, let path = folderIndex[withoutCollection] {
            return path
        }

        // 3. Try without year suffix like "(2010)"
        let withoutYear = normalized.replacingOccurrences(
            of: "\\s*\\(\\d{4}\\)$",
            with: "",
            options: .regularExpression
        )
        if withoutYear != normalized, let path = folderIndex[withoutYear] {
            return path
        }

        // 4. Try series name for episodes (e.g. "Breaking Bad")
        if let seriesName = item.seriesName {
            let normalizedSeries = Self.normalize(seriesName)
            if let path = folderIndex[normalizedSeries] {
                return path
            }
        }

        // 5. For collections, check if any folder key STARTS with the search term
        //    and points to a collection-level covers/ (top-level folder, not subfolder).
        //    This ensures "the lord of the rings" matches the parent folder, not a movie subfolder.
        let searchTerm = withoutCollection != normalized ? withoutCollection : withoutYear
        if isCollection {
            // Collection-level covers paths contain the base cache path + folder + /covers
            // Subfolder covers paths contain base + folder + subfolder + /covers (extra depth)
            let baseDepth = cacheBasePath.components(separatedBy: "/").count + 2 // base/folder/covers
            for (key, path) in folderIndex {
                let stripped = Self.normalize(
                    key.replacingOccurrences(of: "\\s*\\(.*?\\)$", with: "", options: .regularExpression)
                )
                if stripped == searchTerm || key.hasPrefix(searchTerm) {
                    let pathDepth = path.components(separatedBy: "/").count
                    // Only match collection-level (shallow) paths
                    if pathDepth <= baseDepth {
                        return path
                    }
                }
            }
        }

        // 6. Fuzzy: find the best (longest) key match for movies
        var bestMatch: (key: String, path: String)?
        for (key, path) in folderIndex {
            let matches = searchTerm.contains(key) || key.contains(searchTerm)
            if matches {
                if bestMatch == nil || key.count > bestMatch!.key.count {
                    bestMatch = (key, path)
                }
            }
        }
        if let best = bestMatch {
            return best.path
        }

        return nil
    }

    static func normalize(_ name: String) -> String {
        return name
            .lowercased()
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
