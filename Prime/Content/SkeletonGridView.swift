import UIKit

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

