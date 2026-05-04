import UIKit

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
