import UIKit

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

