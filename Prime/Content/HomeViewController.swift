import UIKit

final class HomeViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // private let heroBanner = HeroBannerView() // Shelved for now
    private var continueWatchingRow: MediaRowView?
    private var latestMoviesRow: MediaRowView?
    private var latestShowsRow: MediaRowView?
    private var collectionsRow: MediaRowView?
    private var liveTVWrapper: UIView?

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
        contentStack.spacing = 32
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

        collectionsRow = MediaRowView(title: "Collections")
        collectionsRow?.delegate = self
        collectionsRow?.isHidden = true
        contentStack.addArrangedSubview(paddedWrapper(collectionsRow!))

        // Live TV placeholder — built dynamically after data loads
        let ltvWrapper = UIView()
        ltvWrapper.isHidden = true
        contentStack.addArrangedSubview(ltvWrapper)
        liveTVWrapper = ltvWrapper
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

                // Load collections (BoxSets)
                Task {
                    do {
                        // Try fetching BoxSet items directly
                        var response = try await JellyfinAPI.shared.getItems(
                            includeItemTypes: "BoxSet",
                            sortBy: "SortName",
                            sortOrder: "Ascending",
                            limit: 20
                        )

                        // Fallback: check for a dedicated "boxsets" library
                        if response.items.isEmpty, let boxsetLib = libs.first(where: { $0.collectionType == "boxsets" }) {
                            response = try await JellyfinAPI.shared.getItems(
                                parentId: boxsetLib.id,
                                sortBy: "SortName",
                                sortOrder: "Ascending",
                                limit: 20
                            )
                        }

                        let collections = response.items
                        self.collectionsRow?.setItems(collections)
                        self.collectionsRow?.isHidden = collections.isEmpty
                        self.collectionsRow?.superview?.isHidden = collections.isEmpty
                    } catch {
                        print("[Home] Collections error: \(error)")
                    }
                }

                // Load recently watched Live TV
                Task {
                    await self.buildLiveTVSection()
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
                    rootVC.showDetail(DetailViewController(item: item))
                }
            }
        } else if item.type == "BoxSet" {
            rootVC.showDetail(CollectionViewController(item: item))
        } else {
            rootVC.showDetail(DetailViewController(item: item))
        }
    }
}

// MARK: - Live TV Section (Recently Watched)

extension HomeViewController {
    func buildLiveTVSection() async {
        let recentIds = UserDefaults.standard.array(forKey: "flickerRecentChannels") as? [Int] ?? []
        guard !recentIds.isEmpty else { return }

        // Load all streams to find recent ones
        do {
            let allStreams = try await XtreamAPI.shared.getLiveStreams()
            var streamMap: [Int: XtreamStream] = [:]
            for s in allStreams { streamMap[s.streamId] = s }

            let recentStreams = recentIds.compactMap { streamMap[$0] }
            guard !recentStreams.isEmpty else { return }

            await MainActor.run {
                guard let wrapper = liveTVWrapper else { return }
                wrapper.subviews.forEach { $0.removeFromSuperview() }

                let label = UILabel()
                label.text = "Live TV"
                label.font = .systemFont(ofSize: 32, weight: .bold)
                label.textColor = .white
                label.translatesAutoresizingMaskIntoConstraints = false
                wrapper.addSubview(label)

                let scroll = UIScrollView()
                scroll.showsHorizontalScrollIndicator = false
                scroll.clipsToBounds = false
                scroll.translatesAutoresizingMaskIntoConstraints = false
                wrapper.addSubview(scroll)

                let row = UIStackView()
                row.axis = .horizontal
                row.spacing = 24
                row.translatesAutoresizingMaskIntoConstraints = false
                scroll.addSubview(row)

                for stream in recentStreams.prefix(10) {
                    let cleanName = self.cleanChannelName(stream.name)
                    let card = LiveTVCard(stream: stream, cleanName: cleanName, allStreamsCache: streamMap)
                    card.onSelect = { [weak self] in
                        self?.playLiveTVStream(stream, cleanName: cleanName)
                    }
                    row.addArrangedSubview(card)
                }

                NSLayoutConstraint.activate([
                    label.topAnchor.constraint(equalTo: wrapper.topAnchor),
                    label.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 32),
                    scroll.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 16),
                    scroll.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 32),
                    scroll.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
                    scroll.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
                    scroll.heightAnchor.constraint(equalToConstant: 260),
                    row.topAnchor.constraint(equalTo: scroll.topAnchor),
                    row.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
                    row.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
                    row.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
                    row.heightAnchor.constraint(equalTo: scroll.heightAnchor)
                ])

                wrapper.isHidden = false
            }

            // Load EPG for recent channels
            var epgCache: [Int: XtreamEPGEntry] = [:]
            for batch in stride(from: 0, to: recentStreams.count, by: 5) {
                let end = min(batch + 5, recentStreams.count)
                let batchStreams = Array(recentStreams[batch..<end])
                await withTaskGroup(of: (Int, XtreamEPGEntry?).self) { group in
                    for s in batchStreams {
                        group.addTask {
                            let program = await XtreamAPI.shared.getCurrentProgram(streamId: s.streamId)
                            return (s.streamId, program)
                        }
                    }
                    for await (id, program) in group {
                        if let program { epgCache[id] = program }
                    }
                }
            }

            // Update cards with EPG data
            let finalCache = epgCache
            await MainActor.run {
                guard let wrapper = self.liveTVWrapper else { return }
                self.updateLiveTVCards(in: wrapper, epg: finalCache)
            }
        } catch {
            print("[Home] Live TV error: \(error)")
        }
    }

    private func updateLiveTVCards(in view: UIView, epg: [Int: XtreamEPGEntry]) {
        if let card = view as? LiveTVCard {
            card.updateEPG(from: epg)
        }
        for sub in view.subviews { updateLiveTVCards(in: sub, epg: epg) }
    }

    private func playLiveTVStream(_ stream: XtreamStream, cleanName: String) {
        guard let url = XtreamAPI.shared.streamURL(for: stream.streamId) else { return }
        let playerVC = PlayerViewController(streamURL: url, itemId: nil, title: cleanName, startPositionTicks: 0)
        present(playerVC, animated: true)
    }

    private func cleanChannelName(_ name: String) -> String {
        var clean = name
        if let pipeRange = clean.range(of: "| ") {
            let prefix = String(clean[clean.startIndex..<pipeRange.lowerBound])
            if prefix.count <= 4 { clean = String(clean[pipeRange.upperBound...]) }
        }
        if let pipeRange = clean.range(of: "|") {
            let prefix = String(clean[clean.startIndex..<pipeRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            if prefix.count <= 4 { clean = String(clean[pipeRange.upperBound...]).trimmingCharacters(in: .whitespaces) }
        }
        clean = clean.replacingOccurrences(of: "\\s*(HD|FHD|UHD|SD|4K|HEVC|H265)\\s*$", with: "", options: .regularExpression)
        clean = clean.replacingOccurrences(of: "\\s*\\(.*?\\)\\s*$", with: "", options: .regularExpression)
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
