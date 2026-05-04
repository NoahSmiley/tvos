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

// MARK: - Dominant Color Extraction

extension UIImage {
    /// Extracts the most prominent non-white/non-black color from the image
    var dominantColor: UIColor? {
        guard let cgImage = self.cgImage else { return nil }

        let size = CGSize(width: 8, height: 8)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var rawData = [UInt8](repeating: 0, count: Int(size.width * size.height * 4))

        guard let context = CGContext(
            data: &rawData,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(size.width) * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(origin: .zero, size: size))

        var bestR: CGFloat = 0, bestG: CGFloat = 0, bestB: CGFloat = 0
        var bestSaturation: CGFloat = 0

        for i in stride(from: 0, to: rawData.count, by: 4) {
            let r = CGFloat(rawData[i]) / 255.0
            let g = CGFloat(rawData[i + 1]) / 255.0
            let b = CGFloat(rawData[i + 2]) / 255.0

            let maxC = max(r, g, b)
            let minC = min(r, g, b)
            let saturation = maxC > 0 ? (maxC - minC) / maxC : 0
            let brightness = maxC

            // Skip very dark, very light, or very desaturated colors
            if brightness < 0.15 || brightness > 0.9 { continue }
            if saturation < 0.1 { continue }

            if saturation > bestSaturation {
                bestSaturation = saturation
                bestR = r; bestG = g; bestB = b
            }
        }

        if bestSaturation > 0.1 {
            return UIColor(red: bestR, green: bestG, blue: bestB, alpha: 1)
        }

        return nil
    }

    /// Returns true if the image is mostly dark with no color (pure black logos on transparent)
    var isDark: Bool {
        guard let cgImage = self.cgImage else { return false }

        let size = CGSize(width: 10, height: 10)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var rawData = [UInt8](repeating: 0, count: Int(size.width * size.height * 4))

        guard let context = CGContext(
            data: &rawData,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(size.width) * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }

        context.draw(cgImage, in: CGRect(origin: .zero, size: size))

        var totalBrightness: CGFloat = 0
        var maxSaturation: CGFloat = 0
        var opaquePixels: CGFloat = 0

        for i in stride(from: 0, to: rawData.count, by: 4) {
            let a = CGFloat(rawData[i + 3]) / 255.0
            if a < 0.3 { continue }
            let r = CGFloat(rawData[i]) / 255.0
            let g = CGFloat(rawData[i + 1]) / 255.0
            let b = CGFloat(rawData[i + 2]) / 255.0
            totalBrightness += (r * 0.299 + g * 0.587 + b * 0.114)
            let maxC = max(r, g, b)
            let minC = min(r, g, b)
            if maxC > 0 { maxSaturation = max(maxSaturation, (maxC - minC) / maxC) }
            opaquePixels += 1
        }

        guard opaquePixels > 0 else { return false }
        let avgBrightness = totalBrightness / opaquePixels

        // Only invert if truly dark AND has no color (pure black text logos)
        // Logos like ESPN (red on transparent) have saturation and should NOT be inverted
        return avgBrightness < 0.2 && maxSaturation < 0.3
    }
}
