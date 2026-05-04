import UIKit

/// Reusable shimmer skeleton view with animated gradient sweep.
final class ShimmerView: UIView {

    private let gradientLayer = CAGradientLayer()
    private var isAnimating = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        backgroundColor = UIColor(white: 0.14, alpha: 1)
        clipsToBounds = true
        layer.cornerRadius = 8

        let base = UIColor(white: 0.14, alpha: 1).cgColor
        let highlight = UIColor(white: 0.22, alpha: 1).cgColor

        gradientLayer.colors = [base, highlight, base]
        gradientLayer.locations = [0.0, 0.5, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        layer.addSublayer(gradientLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = CGRect(x: -bounds.width, y: 0, width: bounds.width * 3, height: bounds.height)
        if !isAnimating { startAnimating() }
    }

    func startAnimating() {
        guard !isAnimating else { return }
        isAnimating = true

        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = -bounds.width
        animation.toValue = bounds.width
        animation.duration = 1.5
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        gradientLayer.add(animation, forKey: "shimmer")
    }

    func stopAnimating() {
        isAnimating = false
        gradientLayer.removeAllAnimations()
    }
}

// MARK: - Skeleton Factories

extension ShimmerView {

    /// Creates a poster-shaped skeleton (matches MediaCardCell size)
    static func posterSkeleton() -> ShimmerView {
        let view = ShimmerView()
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 340),
            view.heightAnchor.constraint(equalToConstant: 510)
        ])
        return view
    }

    /// Creates a thumbnail-shaped skeleton (matches ThumbnailCardCell size)
    static func thumbnailSkeleton() -> ShimmerView {
        let view = ShimmerView()
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 480),
            view.heightAnchor.constraint(equalToConstant: 330)
        ])
        return view
    }

    /// Creates a small text-line skeleton
    static func textSkeleton(width: CGFloat = 200, height: CGFloat = 20) -> ShimmerView {
        let view = ShimmerView()
        view.layer.cornerRadius = height / 2
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: width),
            view.heightAnchor.constraint(equalToConstant: height)
        ])
        return view
    }

    /// Creates a circular skeleton (for cast headshots)
    static func circleSkeleton(size: CGFloat = 90) -> ShimmerView {
        let view = ShimmerView()
        view.layer.cornerRadius = size / 2
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: size),
            view.heightAnchor.constraint(equalToConstant: size)
        ])
        return view
    }
}

// MARK: - Skeleton Row (horizontal row of shimmer cards)

