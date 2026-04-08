import UIKit

final class HomeViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // private let heroBanner = HeroBannerView() // Shelved for now
    private var continueWatchingRow: MediaRowView?
    private var latestMoviesRow: MediaRowView?
    private var latestShowsRow: MediaRowView?
    private var liveTVRow: LiveTVRowView?

    private var skeletonRows: [UIView] = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupScrollView()
        setupSkeletons()
        setupRows()
        loadContent()
    }

    private func setupScrollView() {
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        contentStack.axis = .vertical
        contentStack.spacing = 48
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -60),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    private func setupSkeletons() {
        let styles: [SkeletonRowView.SkeletonStyle] = [.poster, .poster, .thumbnail]
        for style in styles {
            let skeleton = SkeletonRowView(style: style)
            let wrapper = paddedWrapper(skeleton)
            contentStack.addArrangedSubview(wrapper)
            skeletonRows.append(wrapper)
        }
    }

    private func removeSkeletons() {
        UIView.animate(withDuration: 0.3) {
            for skeleton in self.skeletonRows {
                skeleton.alpha = 0
            }
        } completion: { _ in
            for skeleton in self.skeletonRows {
                skeleton.removeFromSuperview()
            }
            self.skeletonRows.removeAll()
        }
    }

    private func setupRows() {
        // Hero banner shelved
        // contentStack.addArrangedSubview(heroBanner)
        // heroBanner.delegate = self

        continueWatchingRow = MediaRowView(title: "Continue Watching", style: .thumbnail)
        continueWatchingRow?.delegate = self
        continueWatchingRow?.isHidden = true
        contentStack.addArrangedSubview(paddedWrapper(continueWatchingRow!))

        latestMoviesRow = MediaRowView(title: "Latest Movies")
        latestMoviesRow?.delegate = self
        latestMoviesRow?.isHidden = true
        contentStack.addArrangedSubview(paddedWrapper(latestMoviesRow!))

        latestShowsRow = MediaRowView(title: "Latest Shows")
        latestShowsRow?.delegate = self
        latestShowsRow?.isHidden = true
        contentStack.addArrangedSubview(paddedWrapper(latestShowsRow!))

        liveTVRow = LiveTVRowView(title: "Live TV")
        liveTVRow?.delegate = self
        liveTVRow?.isHidden = true
        contentStack.addArrangedSubview(paddedWrapper(liveTVRow!))
    }

    private func paddedWrapper(_ child: UIView) -> UIView {
        let wrapper = UIView()
        wrapper.addSubview(child)
        child.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            child.topAnchor.constraint(equalTo: wrapper.topAnchor),
            child.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 32),
            child.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -32),
            child.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor)
        ])
        return wrapper
    }

    private func loadContent() {
        Task {
            if !JellyfinAPI.shared.isAuthenticated {
                await JellyfinAPI.shared.autoLogin()
            }

            guard JellyfinAPI.shared.isAuthenticated else {
                removeSkeletons()
                showMessage("Could not connect to Jellyfin.", color: .gray)
                return
            }

            do {
                async let resumeItems = JellyfinAPI.shared.getResumeItems()
                async let libraries = JellyfinAPI.shared.getLibraries()

                let resume = try await resumeItems
                removeSkeletons()
                continueWatchingRow?.setItems(resume)
                continueWatchingRow?.isHidden = resume.isEmpty
                continueWatchingRow?.superview?.isHidden = resume.isEmpty

                let libs = try await libraries

                let movieLib = libs.first { $0.collectionType == "movies" }
                let tvLib = libs.first { $0.collectionType == "tvshows" }

                if let movieLib {
                    let movies = try await JellyfinAPI.shared.getLatestItems(parentId: movieLib.id)
                    latestMoviesRow?.setItems(movies)
                    latestMoviesRow?.isHidden = movies.isEmpty
                    latestMoviesRow?.superview?.isHidden = movies.isEmpty
                }

                if let tvLib {
                    let shows = try await JellyfinAPI.shared.getLatestItems(parentId: tvLib.id)
                    latestShowsRow?.setItems(shows)
                    latestShowsRow?.isHidden = shows.isEmpty
                    latestShowsRow?.superview?.isHidden = shows.isEmpty
                }

                // Load Live TV channels
                Task {
                    do {
                        let categories = try await XtreamAPI.shared.getCategories()
                        if let firstCat = categories.first {
                            let streams = try await XtreamAPI.shared.getLiveStreams(categoryId: firstCat.categoryId)
                            let topStreams = Array(streams.prefix(20))
                            liveTVRow?.setStreams(topStreams)
                            liveTVRow?.isHidden = topStreams.isEmpty
                            liveTVRow?.superview?.isHidden = topStreams.isEmpty
                        }
                    } catch {
                        print("[Home] IPTV error: \(error)")
                    }
                }

            } catch {
                removeSkeletons()
                showMessage(error.localizedDescription, color: UIColor(red: 1, green: 0.4, blue: 0.4, alpha: 1))
            }
        }
    }

    private func showMessage(_ text: String, color: UIColor) {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 28, weight: .medium)
        label.textColor = color
        label.textAlignment = .center
        label.numberOfLines = 0
        contentStack.addArrangedSubview(label)
    }
}

extension HomeViewController: MediaRowDelegate {
    func mediaRowDidSelectItem(_ item: JellyfinItem) {
        guard let rootVC = parent as? RootViewController else { return }

        // For episodes (continue watching), load the series detail page
        if item.type == "Episode", let seriesId = item.seriesId {
            Task {
                do {
                    let series = try await JellyfinAPI.shared.getItem(id: seriesId)
                    rootVC.showDetail(DetailViewController(item: series))
                } catch {
                    // Fallback: show episode detail
                    rootVC.showDetail(DetailViewController(item: item))
                }
            }
        } else {
            rootVC.showDetail(DetailViewController(item: item))
        }
    }
}

// Hero banner delegate kept for when we re-enable it
// extension HomeViewController: HeroBannerDelegate {
//     func heroBannerDidSelectItem(_ item: JellyfinItem) {
//         let detailVC = DetailViewController(item: item)
//         present(detailVC, animated: true)
//     }
// }

extension HomeViewController: LiveTVRowDelegate {
    func liveTVRowDidSelectStream(_ stream: XtreamStream) {
        guard let url = XtreamAPI.shared.streamURL(for: stream.streamId) else { return }
        let playerVC = PlayerViewController(streamURL: url, itemId: nil, title: stream.name, startPositionTicks: 0)
        present(playerVC, animated: true)
    }
}
