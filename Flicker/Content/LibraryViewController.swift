import UIKit

enum LibraryType {
    case movies
    case tvShows

    var jellyfinType: String {
        switch self {
        case .movies: return "Movie"
        case .tvShows: return "Series"
        }
    }

    var title: String {
        switch self {
        case .movies: return "Movies"
        case .tvShows: return "TV Shows"
        }
    }
}

final class LibraryViewController: UIViewController {

    private let libraryType: LibraryType
    private let collectionView: UICollectionView
    private var items: [JellyfinItem] = []
    private var isLoading = false
    private var totalItems = 0
    private var skeletonGrid: SkeletonGridView?

    init(libraryType: LibraryType) {
        self.libraryType = libraryType

        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 340, height: 510)
        layout.minimumInteritemSpacing = 32
        layout.minimumLineSpacing = 40
        layout.sectionInset = UIEdgeInsets(top: 0, left: 48, bottom: 48, right: 48)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupHeader()
        setupCollectionView()
        showSkeleton()
        loadItems()
    }

    private func showSkeleton() {
        let grid = SkeletonGridView(columns: 5, rows: 2)
        grid.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(grid)
        let header = view.viewWithTag(300)!
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 32),
            grid.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 48),
            grid.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -48)
        ])
        skeletonGrid = grid
    }

    private func removeSkeleton() {
        guard let grid = skeletonGrid else { return }
        UIView.animate(withDuration: 0.3) {
            grid.alpha = 0
        } completion: { _ in
            grid.removeFromSuperview()
        }
        skeletonGrid = nil
    }

    private func setupHeader() {
        let label = UILabel()
        label.text = libraryType.title
        label.font = .systemFont(ofSize: 48, weight: .bold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        label.tag = 300

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.topAnchor, constant: 60),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 48)
        ])
    }

    private func setupCollectionView() {
        collectionView.backgroundColor = .clear
        collectionView.register(MediaCardCell.self, forCellWithReuseIdentifier: "MediaCell")
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        let header = view.viewWithTag(300)!
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 32),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func loadItems(startIndex: Int = 0) {
        guard !isLoading, JellyfinAPI.shared.isAuthenticated else { return }
        isLoading = true

        Task {
            do {
                let response = try await JellyfinAPI.shared.getItems(
                    includeItemTypes: libraryType.jellyfinType,
                    sortBy: "DateCreated",
                    sortOrder: "Descending",
                    startIndex: startIndex,
                    limit: 50
                )
                totalItems = response.totalRecordCount
                items.append(contentsOf: response.items)
                removeSkeleton()
                collectionView.reloadData()
            } catch {
                // Show inline error
            }
            isLoading = false
        }
    }
}

extension LibraryViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MediaCell", for: indexPath) as! MediaCardCell
        cell.configure(with: items[indexPath.item])

        // Pagination
        if indexPath.item >= items.count - 10 && items.count < totalItems {
            loadItems(startIndex: items.count)
        }

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let rootVC = parent as? RootViewController {
            rootVC.showDetail(DetailViewController(item: items[indexPath.item]))
        }
    }
}
