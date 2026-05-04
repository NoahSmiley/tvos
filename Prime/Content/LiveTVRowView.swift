import UIKit

protocol LiveTVRowDelegate: AnyObject {
    func liveTVRowDidSelectStream(_ stream: XtreamStream)
}

final class LiveTVRowView: UIView {

    weak var delegate: LiveTVRowDelegate?

    private let titleLabel = UILabel()
    private let collectionView: UICollectionView
    private var streams: [XtreamStream] = []

    private static let cellId = "LiveTVCell"

    init(title: String) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 320, height: 220)
        layout.minimumInteritemSpacing = 24
        layout.minimumLineSpacing = 24
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

        super.init(frame: .zero)

        titleLabel.text = title
        titleLabel.font = AppTheme.font(32, weight: .bold)
        titleLabel.textColor = .white

        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.clipsToBounds = false
        collectionView.register(LiveTVCardCell.self, forCellWithReuseIdentifier: Self.cellId)
        collectionView.dataSource = self
        collectionView.delegate = self

        addSubview(titleLabel)
        addSubview(collectionView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),

            collectionView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: 240)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func setStreams(_ streams: [XtreamStream]) {
        self.streams = streams
        collectionView.reloadData()
    }
}

extension LiveTVRowView: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        streams.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Self.cellId, for: indexPath) as! LiveTVCardCell
        cell.configure(with: streams[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.liveTVRowDidSelectStream(streams[indexPath.item])
    }
}

// MARK: - Live TV Card Cell

final class LiveTVCardCell: UICollectionViewCell {

    private let logoImageView = UIImageView()
    private let nameLabel = UILabel()
    private let liveTag = UILabel()

    private var loadTask: Task<Void, Never>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        contentView.backgroundColor = UIColor(white: 0.12, alpha: 1)
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true

        logoImageView.contentMode = .scaleAspectFit
        logoImageView.clipsToBounds = true
        logoImageView.tintColor = .gray
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(logoImageView)

        nameLabel.font = AppTheme.font(22, weight: .semibold)
        nameLabel.textColor = .white
        nameLabel.numberOfLines = 2
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        liveTag.text = "LIVE"
        liveTag.font = AppTheme.font(14, weight: .bold)
        liveTag.textColor = .white
        liveTag.backgroundColor = AppTheme.liveRed
        liveTag.textAlignment = .center
        liveTag.layer.cornerRadius = 4
        liveTag.clipsToBounds = true
        liveTag.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(liveTag)

        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            logoImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            logoImageView.widthAnchor.constraint(equalToConstant: 80),
            logoImageView.heightAnchor.constraint(equalToConstant: 80),

            nameLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),

            liveTag.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            liveTag.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            liveTag.widthAnchor.constraint(equalToConstant: 42),
            liveTag.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    func configure(with stream: XtreamStream) {
        nameLabel.text = stream.name

        loadTask?.cancel()
        logoImageView.image = UIImage(systemName: "tv")
        if let iconStr = stream.streamIcon, let iconURL = URL(string: iconStr) {
            loadTask = Task {
                let image = await ImageLoader.shared.loadImage(from: iconURL)
                if !Task.isCancelled, let image {
                    logoImageView.image = image
                }
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        loadTask?.cancel()
        logoImageView.image = UIImage(systemName: "tv")
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                self.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                self.contentView.layer.shadowColor = UIColor.white.cgColor
                self.contentView.layer.shadowOpacity = 0.25
                self.contentView.layer.shadowRadius = 16
                self.contentView.layer.shadowOffset = .zero
            } else {
                self.transform = .identity
                self.contentView.layer.shadowOpacity = 0
            }
        }, completion: nil)
    }
}
