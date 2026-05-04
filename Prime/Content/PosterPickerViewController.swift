import UIKit

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
