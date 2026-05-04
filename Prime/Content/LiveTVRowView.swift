import UIKit


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
