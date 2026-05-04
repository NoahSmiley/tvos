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

final class SkeletonRowView: UIView {

    private var shimmers: [ShimmerView] = []

    init(style: SkeletonStyle, count: Int = 6) {
        super.init(frame: .zero)

        let titleShimmer = ShimmerView.textSkeleton(width: 250, height: 28)
        addSubview(titleShimmer)
        titleShimmer.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 36
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        for _ in 0..<count {
            let shimmer: ShimmerView
            switch style {
            case .poster:
                shimmer = ShimmerView.posterSkeleton()
            case .thumbnail:
                shimmer = ShimmerView.thumbnailSkeleton()
            }
            stack.addArrangedSubview(shimmer)
            shimmers.append(shimmer)
        }

        let rowHeight: CGFloat = style == .poster ? 530 : 350

        NSLayoutConstraint.activate([
            titleShimmer.topAnchor.constraint(equalTo: topAnchor),
            titleShimmer.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.topAnchor.constraint(equalTo: titleShimmer.bottomAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: rowHeight + 44)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    enum SkeletonStyle {
        case poster
        case thumbnail
    }
}

// MARK: - Skeleton Grid (for Library view)

final class SkeletonGridView: UIView {

    init(columns: Int = 5, rows: Int = 3) {
        super.init(frame: .zero)

        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 40
        grid.translatesAutoresizingMaskIntoConstraints = false
        addSubview(grid)

        for _ in 0..<rows {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 32
            row.distribution = .fillEqually

            for _ in 0..<columns {
                let shimmer = ShimmerView()
                shimmer.layer.cornerRadius = 12
                shimmer.translatesAutoresizingMaskIntoConstraints = false
                shimmer.heightAnchor.constraint(equalToConstant: 510).isActive = true
                row.addArrangedSubview(shimmer)
            }
            grid.addArrangedSubview(row)
        }

        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: topAnchor),
            grid.leadingAnchor.constraint(equalTo: leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: trailingAnchor),
            grid.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Skeleton Episode Row

final class SkeletonEpisodeRowView: UIView {

    init() {
        super.init(frame: .zero)

        let thumb = ShimmerView()
        thumb.layer.cornerRadius = 8
        thumb.translatesAutoresizingMaskIntoConstraints = false

        let titleLine = ShimmerView.textSkeleton(width: 300, height: 24)
        let subtitleLine = ShimmerView.textSkeleton(width: 500, height: 18)

        let textStack = UIStackView(arrangedSubviews: [titleLine, subtitleLine])
        textStack.axis = .vertical
        textStack.spacing = 12
        textStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(thumb)
        addSubview(textStack)

        NSLayoutConstraint.activate([
            thumb.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            thumb.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            thumb.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            thumb.widthAnchor.constraint(equalToConstant: 300),
            thumb.heightAnchor.constraint(equalToConstant: 169),
            textStack.leadingAnchor.constraint(equalTo: thumb.trailingAnchor, constant: 24),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }
}
