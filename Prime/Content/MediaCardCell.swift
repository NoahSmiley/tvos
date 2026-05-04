import UIKit

final class MediaCardCell: UICollectionViewCell {

    private let posterImageView = UIImageView()
    private let progressBar = UIView()
    private let progressFill = UIView()
    private var progressWidthConstraint: NSLayoutConstraint?

    private var loadTask: Task<Void, Never>?
    private var currentItem: JellyfinItem?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupLongPress()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        clipsToBounds = false
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true

        posterImageView.contentMode = .scaleAspectFill
        posterImageView.clipsToBounds = true
        posterImageView.backgroundColor = UIColor(white: 0.12, alpha: 1)
        posterImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(posterImageView)

        progressBar.backgroundColor = UIColor(white: 0.3, alpha: 1)
        progressBar.layer.cornerRadius = 2
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.isHidden = true
        contentView.addSubview(progressBar)

        progressFill.backgroundColor = AppTheme.textActive
        progressFill.layer.cornerRadius = 2
        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressBar.addSubview(progressFill)

        let progressWidth = progressFill.widthAnchor.constraint(equalToConstant: 0)
        progressWidthConstraint = progressWidth

        NSLayoutConstraint.activate([
            posterImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            posterImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            posterImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            posterImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            progressBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            progressBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            progressBar.heightAnchor.constraint(equalToConstant: 4),

            progressFill.topAnchor.constraint(equalTo: progressBar.topAnchor),
            progressFill.leadingAnchor.constraint(equalTo: progressBar.leadingAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressBar.bottomAnchor),
            progressWidth
        ])
    }

    private func setupLongPress() {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        addGestureRecognizer(longPress)
    }

    func configure(with item: JellyfinItem) {
        currentItem = item

        if let percentage = item.userData?.playedPercentage, percentage > 0 {
            progressBar.isHidden = false
            layoutIfNeeded()
            progressWidthConstraint?.constant = progressBar.bounds.width * CGFloat(percentage / 100.0)
        } else {
            progressBar.isHidden = true
        }

        loadTask?.cancel()
        posterImageView.image = nil

        // Check for custom poster first
        if let customPoster = PosterCacheManager.shared.selectedPoster(for: item) {
            posterImageView.image = customPoster
            return
        }

        loadTask = Task {
            let image = await ImageLoader.shared.loadImage(from: item.bestPosterURL)
            if !Task.isCancelled {
                posterImageView.image = image
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        loadTask?.cancel()
        posterImageView.image = nil
        progressBar.isHidden = true
        currentItem = nil
    }

    // MARK: - Long Press → Poster Picker

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, let item = currentItem else { return }

        let cache = PosterCacheManager.shared
        let count = cache.posterCount(for: item)

        guard count > 1 else { return }

        // Show poster picker
        showPosterPicker(for: item)
    }

    private func showPosterPicker(for item: JellyfinItem) {
        guard let viewController = findViewController() else { return }

        let picker = PosterPickerViewController(item: item)
        picker.onPosterSelected = { [weak self] in
            self?.configure(with: item)
        }
        viewController.present(picker, animated: true)
    }

    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let vc = next as? UIViewController { return vc }
            responder = next
        }
        return nil
    }

    // MARK: - Focus

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                self.transform = CGAffineTransform(scaleX: 1.08, y: 1.08)
                self.contentView.layer.shadowColor = UIColor.white.cgColor
                self.contentView.layer.shadowOpacity = 0.3
                self.contentView.layer.shadowRadius = 20
                self.contentView.layer.shadowOffset = .zero
            } else {
                self.transform = .identity
                self.contentView.layer.shadowOpacity = 0
            }
        }, completion: nil)
    }
}

// MARK: - Poster Picker VC

