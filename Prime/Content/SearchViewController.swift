import UIKit

final class SearchViewController: UIViewController {

    private let searchContainerVC: UISearchContainerViewController
    private let searchController: UISearchController
    private let resultsController = SearchResultsController()
    private var searchTask: Task<Void, Never>?

    override init(nibName: String?, bundle: Bundle?) {
        searchController = UISearchController(searchResultsController: resultsController)
        searchContainerVC = UISearchContainerViewController(searchController: searchController)
        super.init(nibName: nibName, bundle: bundle)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.04, alpha: 1)

        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Movies, Shows..."

        resultsController.onSelect = { [weak self] item in
            if let rootVC = self?.parent as? RootViewController {
                let vc: UIViewController = item.type == "BoxSet"
                    ? CollectionViewController(item: item)
                    : DetailViewController(item: item)
                rootVC.showDetail(vc)
            }
        }

        // Embed the search container as a child VC
        addChild(searchContainerVC)
        view.addSubview(searchContainerVC.view)
        searchContainerVC.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            searchContainerVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            searchContainerVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchContainerVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchContainerVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        searchContainerVC.didMove(toParent: self)
    }

    /// Called by RootViewController when sidebar opens — hide search UI entirely
    func dismissSearch() {
        searchController.searchBar.resignFirstResponder()
        view.endEditing(true)
        searchContainerVC.view.alpha = 0
    }

    /// Called when focus returns to content — show search UI again
    func showSearch() {
        searchContainerVC.view.alpha = 1
    }

    /// Called when search tab is re-selected — activate search
    func activateSearch() {
        searchController.searchBar.becomeFirstResponder()
    }
}

extension SearchViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let query = searchController.searchBar.text ?? ""
        searchTask?.cancel()

        guard query.count >= 2 else {
            resultsController.results = []
            resultsController.collectionView.reloadData()
            return
        }

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }

            do {
                let response = try await JellyfinAPI.shared.getItems(
                    includeItemTypes: "Movie,Series",
                    limit: 30,
                    searchTerm: query
                )
                if !Task.isCancelled {
                    resultsController.results = response.items
                    resultsController.collectionView.reloadData()
                }
            } catch { }
        }
    }
}

// MARK: - Results Controller

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
