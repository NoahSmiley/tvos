import UIKit

final class HomeViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    // private let heroBanner = HeroBannerView() // Shelved for now
    private var mastersWrapper: UIView?
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
        // Masters event row placeholder — built after IPTV data loads
        let mWrapper = UIView()
        mWrapper.isHidden = true
        contentStack.addArrangedSubview(mWrapper)
        mastersWrapper = mWrapper

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

                // Load Masters event + recently watched Live TV
                Task {
                    await self.buildMastersSection()
                    await self.buildLiveTVSection()
                }

            } catch {
                removeSkeletons()
                showMessage(error.localizedDescription, color: UIColor(red: 1, green: 0.4, blue: 0.4, alpha: 1))
            }
        }
    }

    // MARK: - The Masters Event Section

    /// Masters stream IDs — curated for US coverage
    private static let mastersStreamIds: [Int] = [
        // Direct Masters streams
        882044,   // Masters Featured Groups
        882045,   // Mornings at The Masters
        1022187,  // Masters On The Range
        1023137,  // Masters On The Range (alt)
        1023138,  // Masters Featured Groups (alt)
        1949908,  // ESPN+ Masters: Featured Groups
        1949907,  // ESPN+ Masters: Amen Corner
        2051189,  // 8K Masters: Featured Groups
        2051188,  // 8K Masters: Amen Corner
        1910741,  // Paramount Masters On the Range
        // US broadcast channels carrying Masters
        45579,    // ESPN HD
        45604,    // CBS HD
        45601,    // CBS Sports Network HD
        45554,    // Golf Channel HD
    ]

    func buildMastersSection() async {
        do {
            let allStreams = try await XtreamAPI.shared.getLiveStreams()
            var streamMap: [Int: XtreamStream] = [:]
            for s in allStreams { streamMap[s.streamId] = s }

            let mastersStreams = Self.mastersStreamIds.compactMap { streamMap[$0] }
            guard !mastersStreams.isEmpty else { return }

            await MainActor.run {
                guard let wrapper = mastersWrapper else { return }
                wrapper.subviews.forEach { $0.removeFromSuperview() }

                // Masters green theme
                let mastersGreen = UIColor(red: 0.0, green: 0.39, blue: 0.25, alpha: 1.0)
                let mastersGold = UIColor(red: 0.95, green: 0.82, blue: 0.25, alpha: 1.0)

                // Banner container
                let banner = UIView()
                banner.backgroundColor = mastersGreen.withAlphaComponent(0.15)
                banner.layer.cornerRadius = 20
                banner.translatesAutoresizingMaskIntoConstraints = false
                wrapper.addSubview(banner)

                // Left accent stripe
                let stripe = UIView()
                stripe.backgroundColor = mastersGreen
                stripe.layer.cornerRadius = 3
                stripe.translatesAutoresizingMaskIntoConstraints = false
                banner.addSubview(stripe)

                // Header row: logo area + title
                let headerStack = UIStackView()
                headerStack.axis = .horizontal
                headerStack.spacing = 16
                headerStack.alignment = .center
                headerStack.translatesAutoresizingMaskIntoConstraints = false
                banner.addSubview(headerStack)

                // Masters flag icon
                let flagIcon = UIImageView(image: UIImage(systemName: "flag.fill"))
                flagIcon.tintColor = mastersGold
                flagIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 28, weight: .bold)
                headerStack.addArrangedSubview(flagIcon)

                let titleStack = UIStackView()
                titleStack.axis = .vertical
                titleStack.spacing = 2

                let titleLabel = UILabel()
                titleLabel.text = "The Masters"
                titleLabel.font = .systemFont(ofSize: 36, weight: .heavy)
                titleLabel.textColor = mastersGold
                titleStack.addArrangedSubview(titleLabel)

                let subtitleLabel = UILabel()
                subtitleLabel.text = "Augusta National Golf Club · Live Now"
                subtitleLabel.font = .systemFont(ofSize: 20, weight: .medium)
                subtitleLabel.textColor = UIColor(white: 0.6, alpha: 1)
                titleStack.addArrangedSubview(subtitleLabel)

                headerStack.addArrangedSubview(titleStack)

                // LIVE badge
                let liveBadge = UILabel()
                liveBadge.text = "  LIVE  "
                liveBadge.font = .systemFont(ofSize: 16, weight: .heavy)
                liveBadge.textColor = .white
                liveBadge.backgroundColor = UIColor(red: 0.9, green: 0.15, blue: 0.15, alpha: 1)
                liveBadge.layer.cornerRadius = 6
                liveBadge.clipsToBounds = true
                liveBadge.translatesAutoresizingMaskIntoConstraints = false
                banner.addSubview(liveBadge)

                // Channel scroll
                let scroll = UIScrollView()
                scroll.showsHorizontalScrollIndicator = false
                scroll.clipsToBounds = false
                scroll.translatesAutoresizingMaskIntoConstraints = false
                banner.addSubview(scroll)

                let row = UIStackView()
                row.axis = .horizontal
                row.spacing = 24
                row.translatesAutoresizingMaskIntoConstraints = false
                scroll.addSubview(row)

                for stream in mastersStreams {
                    let cleanName = self.cleanMastersName(stream.name)
                    let card = MastersChannelCard(stream: stream, cleanName: cleanName, mastersGreen: mastersGreen)
                    card.onSelect = { [weak self] in
                        self?.playLiveTVStream(stream, cleanName: cleanName)
                    }
                    row.addArrangedSubview(card)
                }

                NSLayoutConstraint.activate([
                    banner.topAnchor.constraint(equalTo: wrapper.topAnchor),
                    banner.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 32),
                    banner.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -32),
                    banner.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),

                    stripe.topAnchor.constraint(equalTo: banner.topAnchor, constant: 20),
                    stripe.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 24),
                    stripe.widthAnchor.constraint(equalToConstant: 6),
                    stripe.bottomAnchor.constraint(equalTo: headerStack.bottomAnchor),

                    headerStack.topAnchor.constraint(equalTo: banner.topAnchor, constant: 24),
                    headerStack.leadingAnchor.constraint(equalTo: stripe.trailingAnchor, constant: 16),

                    liveBadge.centerYAnchor.constraint(equalTo: headerStack.centerYAnchor),
                    liveBadge.leadingAnchor.constraint(equalTo: headerStack.trailingAnchor, constant: 16),

                    scroll.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 24),
                    scroll.leadingAnchor.constraint(equalTo: banner.leadingAnchor, constant: 24),
                    scroll.trailingAnchor.constraint(equalTo: banner.trailingAnchor, constant: -24),
                    scroll.bottomAnchor.constraint(equalTo: banner.bottomAnchor, constant: -24),
                    scroll.heightAnchor.constraint(equalToConstant: 200),

                    row.topAnchor.constraint(equalTo: scroll.topAnchor),
                    row.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
                    row.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
                    row.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
                    row.heightAnchor.constraint(equalTo: scroll.heightAnchor)
                ])

                wrapper.isHidden = false
            }
        } catch {
            print("[Home] Masters section error: \(error)")
        }
    }

    private func cleanMastersName(_ name: String) -> String {
        var clean = name
        // Strip provider prefixes
        for prefix in ["US| ", "USA| ", "US (ESPN+ ", "US (Paramount ", "CA (TSN+ ", "LIVE EVENT ", "LIVE | "] {
            if clean.hasPrefix(prefix) { clean = String(clean.dropFirst(prefix.count)) }
        }
        // Strip trailing timestamps/dates
        clean = clean.replacingOccurrences(of: "\\s*\\(\\d{4}-.*$", with: "", options: .regularExpression)
        clean = clean.replacingOccurrences(of: "\\s*\\|.*$", with: "", options: .regularExpression)
        clean = clean.replacingOccurrences(of: "\\s*@.*$", with: "", options: .regularExpression)
        // Clean up common patterns
        clean = clean.replacingOccurrences(of: "_ ", with: ": ")
        clean = clean.replacingOccurrences(of: "  ", with: " ")
        clean = clean.replacingOccurrences(of: "\\d+\\) ", with: "", options: .regularExpression)
        clean = clean.replacingOccurrences(of: "^\\d+\\s*-\\s*\\d+[aApP][mM]\\s*", with: "", options: .regularExpression)
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
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

// MARK: - Masters Channel Card

final class MastersChannelCard: UIButton {

    var onSelect: (() -> Void)?
    private let logoImageView = UIImageView()
    private let nameLabel = UILabel()
    private let liveDot = UIView()
    private var loadTask: Task<Void, Never>?

    init(stream: XtreamStream, cleanName: String, mastersGreen: UIColor) {
        super.init(frame: .zero)

        let darkGreen = UIColor(red: 0.0, green: 0.28, blue: 0.18, alpha: 1.0)
        backgroundColor = darkGreen
        layer.cornerRadius = 14
        clipsToBounds = true
        layer.borderWidth = 1.5
        layer.borderColor = mastersGreen.withAlphaComponent(0.4).cgColor

        // Logo
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.clipsToBounds = true
        logoImageView.tintColor = UIColor(white: 0.4, alpha: 1)
        logoImageView.image = UIImage(systemName: "sportscourt.fill")
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(logoImageView)

        // Channel name
        nameLabel.text = cleanName
        nameLabel.font = .systemFont(ofSize: 20, weight: .bold)
        nameLabel.textColor = .white
        nameLabel.numberOfLines = 2
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nameLabel)

        // Live dot
        liveDot.backgroundColor = UIColor(red: 0.9, green: 0.15, blue: 0.15, alpha: 1)
        liveDot.layer.cornerRadius = 5
        liveDot.translatesAutoresizingMaskIntoConstraints = false
        addSubview(liveDot)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 260),
            heightAnchor.constraint(equalToConstant: 180),

            logoImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -24),
            logoImageView.widthAnchor.constraint(equalToConstant: 120),
            logoImageView.heightAnchor.constraint(equalToConstant: 70),

            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            nameLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),

            liveDot.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            liveDot.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            liveDot.widthAnchor.constraint(equalToConstant: 10),
            liveDot.heightAnchor.constraint(equalToConstant: 10)
        ])

        // Pulse the live dot
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1.0
        pulse.toValue = 0.3
        pulse.duration = 1.0
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        liveDot.layer.add(pulse, forKey: "pulse")

        // Load channel logo
        if let iconStr = stream.streamIcon, !iconStr.isEmpty, let url = URL(string: iconStr) {
            loadTask = Task {
                let img = await ImageLoader.shared.loadImage(from: url)
                if !Task.isCancelled, let img {
                    if img.isDark {
                        logoImageView.image = img.withRenderingMode(.alwaysTemplate)
                        logoImageView.tintColor = .white
                    } else {
                        logoImageView.image = img
                        logoImageView.tintColor = nil
                    }
                }
            }
        }

        addTarget(self, action: #selector(tapped), for: .primaryActionTriggered)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func tapped() { onSelect?() }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        let mastersGold = UIColor(red: 0.95, green: 0.82, blue: 0.25, alpha: 1.0)
        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                self.transform = CGAffineTransform(scaleX: 1.06, y: 1.06)
                self.layer.borderColor = mastersGold.cgColor
                self.layer.borderWidth = 2.5
                self.layer.shadowColor = mastersGold.cgColor
                self.layer.shadowOpacity = 0.4
                self.layer.shadowRadius = 16
                self.layer.shadowOffset = .zero
            } else {
                self.transform = .identity
                self.layer.borderColor = UIColor(red: 0.0, green: 0.39, blue: 0.25, alpha: 0.4).cgColor
                self.layer.borderWidth = 1.5
                self.layer.shadowOpacity = 0
            }
        }, completion: nil)
    }
}
