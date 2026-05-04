import UIKit

final class SearchResultsController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

    let collectionView: UICollectionView
    var results: [JellyfinItem] = []
    var onSelect: ((JellyfinItem) -> Void)?

    override init(nibName: String?, bundle: Bundle?) {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 400, height: 600)
        layout.minimumInteritemSpacing = 44
        layout.minimumLineSpacing = 60
        layout.sectionInset = UIEdgeInsets(top: 24, left: 48, bottom: 48, right: 48)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nibName, bundle: bundle)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        collectionView.backgroundColor = .clear
        collectionView.register(MediaCardCell.self, forCellWithReuseIdentifier: "SearchCell")
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        results.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SearchCell", for: indexPath) as! MediaCardCell
        cell.configure(with: results[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onSelect?(results[indexPath.item])
    }
}
