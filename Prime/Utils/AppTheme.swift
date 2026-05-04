import UIKit

/// Athion design tokens. Mirrors the web design system:
/// monochrome dark palette + OpenAI Sans typography.
/// Color exceptions documented in /docs/stacks/tvos.
enum AppTheme {

    // MARK: - Colors (mirrors --a-* tokens on athion.me)

    /// Background. Same as athion.me #060606.
    static let background = UIColor(white: 0.024, alpha: 1)            // #060606

    /// Elevated surface (sheets, modals, cards).
    static let surface = UIColor(white: 0.039, alpha: 1)               // #0a0a0a

    /// Slightly lifted surface (input bg, search pill).
    static let inputBackground = UIColor(white: 0.067, alpha: 1)       // #111

    /// Primary text.
    static let text = UIColor(white: 0.784, alpha: 1)                  // #c8c8c8

    /// Secondary / muted text.
    static let textMuted = UIColor(white: 0.510, alpha: 1)             // #828282

    /// Tertiary / metadata text.
    static let textFaint = UIColor(white: 0.333, alpha: 1)             // #555

    /// Headings + active state.
    static let textActive = UIColor.white                              // #fff

    /// Structural divider.
    static let border = UIColor(white: 0.102, alpha: 1)                // #1a1a1a

    /// Stronger border (input, card outline).
    static let borderStrong = UIColor(white: 0.165, alpha: 1)          // #2a2a2a

    /// Errors and destructive actions.
    static let error = UIColor(red: 0.80, green: 0.27, blue: 0.27, alpha: 1)   // #c44

    // MARK: - Documented color exceptions (tvOS-specific semantic state)

    /// LIVE broadcast badge. Universal TV-app convention.
    static let liveRed = UIColor(red: 0.90, green: 0.15, blue: 0.15, alpha: 1)

    /// IMDb-style rating star. Universal review-score convention.
    static let ratingGold = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1)

    /// Connected / healthy operational status.
    static let statusOk = UIColor(red: 0.30, green: 0.80, blue: 0.30, alpha: 1)

    /// Disconnected / unhealthy operational status. Same hue as `error`.
    static let statusBad = error

    // MARK: - Type

    enum FontWeight {
        case light, regular, medium, semibold, bold

        fileprivate var fontName: String {
            switch self {
            case .light:    return "OpenAISans-Light"
            case .regular:  return "OpenAISans-Regular"
            case .medium:   return "OpenAISans-Medium"
            case .semibold: return "OpenAISans-Semibold"
            case .bold:     return "OpenAISans-Bold"
            }
        }
    }

    /// Returns OpenAI Sans at the requested size + weight, or the system font
    /// if the family failed to register (defensive — should not happen).
    static func font(_ size: CGFloat, weight: FontWeight = .regular) -> UIFont {
        UIFont(name: weight.fontName, size: size) ?? .systemFont(ofSize: size, weight: systemFallback(for: weight))
    }

    private static func systemFallback(for weight: FontWeight) -> UIFont.Weight {
        switch weight {
        case .light:    return .light
        case .regular:  return .regular
        case .medium:   return .medium
        case .semibold: return .semibold
        case .bold:     return .bold
        }
    }
}
