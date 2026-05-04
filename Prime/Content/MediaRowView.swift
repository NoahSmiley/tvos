import UIKit

enum MediaRowStyle {
    case poster     // Vertical movie/show posters (300x450)
    case thumbnail  // Horizontal episode/continue watching cards (400x280)
}

protocol MediaRowDelegate: AnyObject {
    func mediaRowDidSelectItem(_ item: JellyfinItem)
}

final class MediaRowView: UIView {

    weak var delegate: MediaRowDelegate?

    private let titleLabel = UILabel()
    private let collectionView: UICollectionView
    private let style: MediaRowStyle
    private var items: [JellyfinItem] = []

    private static let posterCellId = "PosterCell"
    private static let thumbCellId = "ThumbCell"

    init(title: String, style: MediaRowStyle = .poster) {
        self.style = style

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 44
        layout.minimumLineSpacing = 44

        switch style {
        case .poster:
            layout.itemSize = CGSize(width: 400, height: 600)
        case .thumbnail:
            layout.itemSize = CGSize(width: 480, height: 330)
        }

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

        super.init(frame: .zero)

        titleLabel.text = title
        titleLabel.font = AppTheme.font(32, weight: .bold)
        titleLabel.textColor = .white

        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.clipsToBounds = false
        collectionView.register(MediaCardCell.self, forCellWithReuseIdentifier: Self.posterCellId)
        collectionView.register(ThumbnailCardCell.self, forCellWithReuseIdentifier: Self.thumbCellId)
        collectionView.dataSource = self
        collectionView.delegate = self

        addSubview(titleLabel)
        addSubview(collectionView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false

        let rowHeight: CGFloat = style == .poster ? 630 : 350

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),

            collectionView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: rowHeight)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func setItems(_ items: [JellyfinItem]) {
        self.items = items
        collectionView.reloadData()
    }
}

extension MediaRowView: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let item = items[indexPath.item]

        switch style {
        case .poster:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Self.posterCellId, for: indexPath) as! MediaCardCell
            cell.configure(with: item)
            return cell
        case .thumbnail:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Self.thumbCellId, for: indexPath) as! ThumbnailCardCell
            cell.configure(with: item)
            return cell
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.mediaRowDidSelectItem(items[indexPath.item])
    }
}
