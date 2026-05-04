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

final class PosterPickerViewController: UIViewController {

    private let item: JellyfinItem
    private let collectionView: UICollectionView
    private var thumbnails: [UIImage] = []
    var onPosterSelected: (() -> Void)?

    init(item: JellyfinItem) {
        self.item = item

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 200, height: 300)
        layout.minimumInteritemSpacing = 24
        layout.sectionInset = UIEdgeInsets(top: 0, left: 48, bottom: 0, right: 48)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadThumbnails()
    }

    private func setupUI() {
        // Dimmed background
        view.backgroundColor = UIColor.black.withAlphaComponent(0.85)

        let titleLabel = UILabel()
        titleLabel.text = "Choose Poster"
        titleLabel.font = AppTheme.font(42, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        let subtitleLabel = UILabel()
        subtitleLabel.text = item.name
        subtitleLabel.font = AppTheme.font(28, weight: .medium)
        subtitleLabel.textColor = UIColor(white: 0.6, alpha: 1)
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)

        collectionView.backgroundColor = .clear
        collectionView.clipsToBounds = false
        collectionView.register(PosterPickerCell.self, forCellWithReuseIdentifier: "PosterCell")
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        let resetButton = UIButton(type: .system)
        resetButton.setTitle("Use Default Poster", for: .normal)
        resetButton.titleLabel?.font = AppTheme.font(24, weight: .semibold)
        resetButton.tintColor = UIColor(white: 0.5, alpha: 1)
        resetButton.addTarget(self, action: #selector(resetTapped), for: .primaryActionTriggered)
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(resetButton)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 120),

            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),

            collectionView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 20),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: 340),

            resetButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            resetButton.topAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: 40)
        ])
    }

    private func loadThumbnails() {
        Task {
            thumbnails = PosterCacheManager.shared.loadPosterThumbnails(for: item)
            collectionView.reloadData()
        }
    }

    @objc private func resetTapped() {
        PosterCacheManager.shared.clearSelection(for: item)
        onPosterSelected?()
        dismiss(animated: true)
    }
}

extension PosterPickerViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ cv: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        thumbnails.count
    }

    func collectionView(_ cv: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "PosterCell", for: indexPath) as! PosterPickerCell
        let isSelected = (PosterCacheManager.shared.selectedIndex(for: item.id) ?? 0) == indexPath.item
        cell.configure(image: thumbnails[indexPath.item], isSelected: isSelected)
        return cell
    }

    func collectionView(_ cv: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        PosterCacheManager.shared.selectPoster(at: indexPath.item, for: item)
        onPosterSelected?()
        dismiss(animated: true)
    }
}

// MARK: - Poster Picker Cell

final class PosterPickerCell: UICollectionViewCell {

    private let imageView = UIImageView()
    private let checkmark = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)

        checkmark.image = UIImage(systemName: "checkmark.circle.fill")
        checkmark.tintColor = AppTheme.textActive
        checkmark.translatesAutoresizingMaskIntoConstraints = false
        checkmark.isHidden = true
        contentView.addSubview(checkmark)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            checkmark.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            checkmark.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            checkmark.widthAnchor.constraint(equalToConstant: 32),
            checkmark.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(image: UIImage, isSelected: Bool) {
        imageView.image = image
        checkmark.isHidden = !isSelected
        contentView.layer.borderWidth = isSelected ? 3 : 0
        contentView.layer.borderColor = AppTheme.textActive.cgColor
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                self.transform = CGAffineTransform(scaleX: 1.12, y: 1.12)
                self.contentView.layer.shadowColor = UIColor.white.cgColor
                self.contentView.layer.shadowOpacity = 0.5
                self.contentView.layer.shadowRadius = 16
                self.contentView.layer.shadowOffset = .zero
            } else {
                self.transform = .identity
                self.contentView.layer.shadowOpacity = 0
            }
        }, completion: nil)
    }
}
