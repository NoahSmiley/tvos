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
        view.backgroundColor = AppTheme.background

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

