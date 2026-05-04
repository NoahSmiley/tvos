import UIKit

final class CollectionMovieCard: UIButton {

    var onSelect: (() -> Void)?
    private let posterImageView = UIImageView()
    private var loadTask: Task<Void, Never>?

    init(item: JellyfinItem) {
        super.init(frame: .zero)

        layer.cornerRadius = 12
        clipsToBounds = true

        posterImageView.contentMode = .scaleAspectFill
        posterImageView.clipsToBounds = true
        posterImageView.backgroundColor = UIColor(white: 0.12, alpha: 1)
        posterImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(posterImageView)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 400),
            heightAnchor.constraint(equalToConstant: 600),
            posterImageView.topAnchor.constraint(equalTo: topAnchor),
            posterImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            posterImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            posterImageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // Load poster
        if let custom = PosterCacheManager.shared.selectedPoster(for: item) {
            posterImageView.image = custom
        } else {
            loadTask = Task {
                let image = await ImageLoader.shared.loadImage(from: item.bestPosterURL)
                if !Task.isCancelled { posterImageView.image = image }
            }
        }

        addTarget(self, action: #selector(tapped), for: .primaryActionTriggered)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func tapped() { onSelect?() }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                self.transform = CGAffineTransform(scaleX: 1.08, y: 1.08)
                self.layer.shadowColor = UIColor.white.cgColor
                self.layer.shadowOpacity = 0.3
                self.layer.shadowRadius = 20
                self.layer.shadowOffset = .zero
            } else {
                self.transform = .identity
                self.layer.shadowOpacity = 0
            }
        }, completion: nil)
    }
}
