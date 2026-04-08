import UIKit

final class ImageLoader {

    static let shared = ImageLoader()

    private let cache = NSCache<NSString, UIImage>()
    private var activeTasks: [String: Task<UIImage?, Never>] = [:]
    private let queue = DispatchQueue(label: "com.flicker.imageloader", attributes: .concurrent)

    private init() {
        cache.countLimit = 300
        cache.totalCostLimit = 100 * 1024 * 1024 // 100 MB
    }

    func loadImage(from url: URL?) async -> UIImage? {
        guard let url else { return nil }
        let key = url.absoluteString as NSString

        if let cached = cache.object(forKey: key) {
            return cached
        }

        // Coalesce duplicate requests
        if let existing = queue.sync(execute: { activeTasks[url.absoluteString] }) {
            return await existing.value
        }

        let task = Task<UIImage?, Never> {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = UIImage(data: data) else { return nil }
                cache.setObject(image, forKey: key, cost: data.count)
                return image
            } catch {
                return nil
            }
        }

        queue.sync(flags: .barrier) {
            activeTasks[url.absoluteString] = task
        }

        let result = await task.value

        queue.sync(flags: .barrier) {
            activeTasks.removeValue(forKey: url.absoluteString)
        }

        return result
    }

    func clearCache() {
        cache.removeAllObjects()
    }
}
