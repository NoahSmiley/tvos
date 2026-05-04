import UIKit

final class LiveTVViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private var sectionViews: [UIView] = []

    // Mapped categories: display name -> category IDs
    private static let sectionOrder: [(name: String, keywords: [String])] = [
        ("Entertainment", ["ENTERTAINMENT"]),
        ("Sports", ["SPORTS"]),
        ("News", ["NEWS"]),
        ("Kids", ["KIDS"]),
        ("Movies", ["MOVIES"]),
        ("Music", ["MUSIC"]),
        ("Lifestyle", ["SPECTRUM", "PEACOCK", "PRIME", "DIREC"]),
        ("4K Ultra HD", ["4K"]),
    ]

    private var categorySections: [(name: String, streams: [XtreamStream])] = []
    private var allStreamsCache: [Int: XtreamStream] = [:]
    private var skeletonView: UIView?
    private var searchQuery = ""
    private var epgCache: [Int: XtreamEPGEntry] = [:] // streamId -> current program
    private var epgLoadTask: Task<Void, Never>?

    private var favorites: Set<Int> {
        get { Set(UserDefaults.standard.array(forKey: "flickerFavoriteChannels") as? [Int] ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: "flickerFavoriteChannels") }
    }

    private var recentChannelIds: [Int] {
        get { UserDefaults.standard.array(forKey: "flickerRecentChannels") as? [Int] ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "flickerRecentChannels") }
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupLayout()
        showSkeleton()
        loadAllData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !categorySections.isEmpty { rebuildUI() }
    }

    // MARK: - Layout

    private func setupLayout() {
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 40
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 50),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -60),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        // Header
        let headerRow = UIView()
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        let titleLabel = UILabel()
        titleLabel.text = "Live TV"
        titleLabel.font = AppTheme.font(48, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerRow.addSubview(titleLabel)

        let searchButton = UIButton(type: .system)
        let searchIcon = UIImage(systemName: "magnifyingglass", withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium))
        searchButton.setImage(searchIcon, for: .normal)
        searchButton.setTitle("  Search channels", for: .normal)
        searchButton.titleLabel?.font = AppTheme.font(22, weight: .medium)
        searchButton.tintColor = UIColor(white: 0.5, alpha: 1)
        searchButton.backgroundColor = UIColor(white: 0.08, alpha: 1)
        searchButton.layer.cornerRadius = 16
        searchButton.contentHorizontalAlignment = .left
        searchButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        searchButton.translatesAutoresizingMaskIntoConstraints = false
        searchButton.addTarget(self, action: #selector(searchTapped), for: .primaryActionTriggered)
        headerRow.addSubview(searchButton)

        NSLayoutConstraint.activate([
            headerRow.heightAnchor.constraint(equalToConstant: 56),
            titleLabel.leadingAnchor.constraint(equalTo: headerRow.leadingAnchor, constant: 48),
            titleLabel.centerYAnchor.constraint(equalTo: headerRow.centerYAnchor),
            searchButton.trailingAnchor.constraint(equalTo: headerRow.trailingAnchor, constant: -48),
            searchButton.centerYAnchor.constraint(equalTo: headerRow.centerYAnchor),
            searchButton.widthAnchor.constraint(equalToConstant: 320),
            searchButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        contentStack.addArrangedSubview(headerRow)
    }

    // MARK: - Skeleton

    private func showSkeleton() {
        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        let title = ShimmerView.textSkeleton(width: 200, height: 28)
        title.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(title)

        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 24
        row.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(row)

        for _ in 0..<5 {
            let card = ShimmerView()
            card.layer.cornerRadius = 14
            card.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                card.widthAnchor.constraint(equalToConstant: 300),
                card.heightAnchor.constraint(equalToConstant: 220)
            ])
            row.addArrangedSubview(card)
        }

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: wrapper.topAnchor),
            title.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 48),
            row.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 16),
            row.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 48),
            row.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor)
        ])
        contentStack.addArrangedSubview(wrapper)
        skeletonView = wrapper
    }

    private func removeSkeleton() {
        guard let sv = skeletonView else { return }
        UIView.animate(withDuration: 0.3) { sv.alpha = 0 } completion: { _ in sv.removeFromSuperview() }
        skeletonView = nil
    }

    // MARK: - Data Loading

    private func loadAllData() {
        Task {
            do {
                // Step 1: Load categories (fast)
                let allCats = try await XtreamAPI.shared.getCategories()

                // Step 2: Map categories to our sections
                var sectionCatIds: [(name: String, catIds: [String])] = []
                for section in Self.sectionOrder {
                    var ids: [String] = []
                    for cat in allCats {
                        let catName = cat.categoryName.uppercased()
                        if section.keywords.contains(where: { catName.contains($0) }) &&
                           (catName.hasPrefix("US") || catName.contains("4K")) {
                            ids.append(cat.categoryId)
                        }
                    }
                    if !ids.isEmpty {
                        sectionCatIds.append((name: section.name, catIds: ids))
                    }
                }

                removeSkeleton()

                // Step 3: Load each section's streams in parallel, show each as it arrives
                await withTaskGroup(of: (String, [XtreamStream]).self) { group in
                    for section in sectionCatIds {
                        group.addTask {
                            var allStreams: [XtreamStream] = []
                            for catId in section.catIds {
                                if let streams = try? await XtreamAPI.shared.getLiveStreams(categoryId: catId) {
                                    allStreams.append(contentsOf: streams)
                                }
                            }
                            return (section.name, allStreams)
                        }
                    }

                    for await (sectionName, streams) in group {
                        // Filter and cache
                        let junkPatterns = ["#####", "NO SIGNAL", "NO EVENT", "EVENT ONLY", "OFF AIR",
                                           "[OFFLINE]", "NOT AVAILABLE", "COMING SOON"]
                        let filtered = streams.filter { stream in
                            let upper = stream.name.uppercased()
                            if junkPatterns.contains(where: { upper.contains($0) }) { return false }
                            if upper.contains("|") {
                                let prefix = upper.components(separatedBy: "|").first?.trimmingCharacters(in: .whitespaces) ?? ""
                                if prefix != "US" && prefix != "4K" && !prefix.isEmpty { return false }
                            }
                            return true
                        }

                        for s in filtered { allStreamsCache[s.streamId] = s }

                        let grouped = groupStreams(filtered)
                        let deduped = grouped.map { $0.primaryStream }

                        if !deduped.isEmpty {
                            categorySections.append((name: sectionName, streams: deduped))
                            // Re-sort sections to match our preferred order
                            let order = Self.sectionOrder.map { $0.name }
                            categorySections.sort { a, b in
                                (order.firstIndex(of: a.name) ?? 99) < (order.firstIndex(of: b.name) ?? 99)
                            }
                            rebuildUI()
                        }
                    }
                }

                // Step 4: Load EPG for all channels
                loadEPGForAllChannels()
            } catch {
                removeSkeleton()
            }
        }
    }

    private func buildSections(categories: [XtreamCategory], streams: [XtreamStream]) {
        // Map category IDs to our section names
        var catToSection: [String: String] = [:]
        for section in Self.sectionOrder {
            for cat in categories {
                let catName = cat.categoryName.uppercased()
                if section.keywords.contains(where: { catName.contains($0) }) &&
                   (catName.hasPrefix("US") || catName.contains("4K")) {
                    catToSection[cat.categoryId] = section.name
                }
            }
        }

        // Group streams into sections
        var sectionStreams: [String: [XtreamStream]] = [:]
        let junkPatterns = ["#####", "NO SIGNAL", "NO EVENT", "EVENT ONLY", "OFF AIR",
                           "[OFFLINE]", "NOT AVAILABLE", "COMING SOON"]

        for stream in streams {
            let upper = stream.name.uppercased()

            // Filter junk
            if junkPatterns.contains(where: { upper.contains($0) }) { continue }

            // Only US/4K channels
            if upper.contains("|") {
                let prefix = upper.components(separatedBy: "|").first?.trimmingCharacters(in: .whitespaces) ?? ""
                if prefix != "US" && prefix != "4K" && !prefix.isEmpty { continue }
            }

            // Find section
            if let catId = stream.categoryId, let section = catToSection[catId] {
                sectionStreams[section, default: []].append(stream)
            }
        }

        // Build ordered sections
        categorySections = []
        for section in Self.sectionOrder {
            if let streams = sectionStreams[section.name], !streams.isEmpty {
                // Deduplicate within section
                let grouped = groupStreams(streams)
                let deduped = grouped.map { $0.primaryStream }
                categorySections.append((name: section.name, streams: deduped))
            }
        }
    }

    private func groupStreams(_ streams: [XtreamStream]) -> [ChannelGroup] {
        var groupDict: [String: [XtreamStream]] = [:]
        var groupOrder: [String] = []
        for stream in streams {
            let base = baseChannelName(stream.name)
            if groupDict[base] == nil { groupOrder.append(base) }
            groupDict[base, default: []].append(stream)
        }
        return groupOrder.compactMap { base in
            guard let streams = groupDict[base] else { return nil }
            let icon = streams.first(where: { $0.streamIcon != nil })?.streamIcon
            return ChannelGroup(baseName: titleCase(base), streams: streams, icon: icon)
        }
    }

    struct ChannelGroup {
        let baseName: String
        let streams: [XtreamStream]
        let icon: String?
        var primaryStream: XtreamStream { streams[0] }
        var hasVariants: Bool { streams.count > 1 }
    }

    // MARK: - UI Building

    private func rebuildUI() {
        // Remove old sections
        for v in sectionViews { v.removeFromSuperview() }
        sectionViews.removeAll()

        // Recently Watched
        let recentContainer = buildRecentSection()
        if let rc = recentContainer {
            contentStack.addArrangedSubview(rc)
            sectionViews.append(rc)
        }

        // Category sections
        for section in categorySections {
            var filtered = section.streams
            if !searchQuery.isEmpty {
                let q = searchQuery.lowercased()
                filtered = filtered.filter { cleanChannelName($0.name).lowercased().contains(q) }
            }
            guard !filtered.isEmpty else { continue }

            let sectionView = buildSection(title: section.name, streams: filtered)
            contentStack.addArrangedSubview(sectionView)
            sectionViews.append(sectionView)
        }
    }

    private func buildSection(title: String, streams: [XtreamStream]) -> UIView {
        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = title
        label.font = AppTheme.font(32, weight: .bold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(label)

        let countLabel = UILabel()
        countLabel.text = "\(streams.count) channels"
        countLabel.font = AppTheme.font(20)
        countLabel.textColor = UIColor(white: 0.4, alpha: 1)
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(countLabel)

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

        for stream in streams {
            let card = LiveTVCard(stream: stream, cleanName: cleanChannelName(stream.name), allStreamsCache: allStreamsCache)
            card.onSelect = { [weak self] in
                self?.playStream(stream, title: self?.cleanChannelName(stream.name) ?? stream.name)
            }
            card.onFavorite = { [weak self] in
                self?.toggleFavorite(streamId: stream.streamId)
            }
            row.addArrangedSubview(card)
        }

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: wrapper.topAnchor),
            label.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 48),
            countLabel.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 12),
            countLabel.bottomAnchor.constraint(equalTo: label.bottomAnchor, constant: -2),
            scroll.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 16),
            scroll.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 48),
            scroll.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            scroll.heightAnchor.constraint(equalToConstant: 260),
            row.topAnchor.constraint(equalTo: scroll.topAnchor),
            row.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            row.heightAnchor.constraint(equalTo: scroll.heightAnchor)
        ])

        return wrapper
    }

    private func buildRecentSection() -> UIView? {
        let recentIds = recentChannelIds
        guard !recentIds.isEmpty else { return nil }

        let streams = recentIds.compactMap { allStreamsCache[$0] }
        guard !streams.isEmpty else { return nil }

        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = "Recently Watched"
        label.font = AppTheme.font(32, weight: .bold)
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

        for stream in streams.prefix(10) {
            let card = LiveTVCard(stream: stream, cleanName: cleanChannelName(stream.name), allStreamsCache: allStreamsCache)
            card.onSelect = { [weak self] in
                self?.playStream(stream, title: self?.cleanChannelName(stream.name) ?? stream.name)
            }
            row.addArrangedSubview(card)
        }

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: wrapper.topAnchor),
            label.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 48),
            scroll.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 16),
            scroll.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 48),
            scroll.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            scroll.heightAnchor.constraint(equalToConstant: 260),
            row.topAnchor.constraint(equalTo: scroll.topAnchor),
            row.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            row.heightAnchor.constraint(equalTo: scroll.heightAnchor)
        ])

        return wrapper
    }

    private func refreshRecentRow() {
        // Rebuild entire UI since sections might change
        if !categorySections.isEmpty { rebuildUI() }
    }

    // MARK: - Batch EPG Loading

    private func loadEPGForAllChannels() {
        epgLoadTask?.cancel()

        // Collect ALL unique stream IDs — recently watched first, then all sections
        var streamIds: [Int] = []
        for id in recentChannelIds {
            if !streamIds.contains(id) { streamIds.append(id) }
        }
        for section in categorySections {
            for stream in section.streams {
                if !streamIds.contains(stream.streamId) {
                    streamIds.append(stream.streamId)
                }
            }
        }

        epgLoadTask = Task {
            // Process 10 at a time — aggressive but the API can handle it
            for batch in stride(from: 0, to: streamIds.count, by: 10) {
                guard !Task.isCancelled else { return }
                let end = min(batch + 10, streamIds.count)
                let batchIds = Array(streamIds[batch..<end])

                await withTaskGroup(of: (Int, XtreamEPGEntry?).self) { group in
                    for id in batchIds {
                        group.addTask {
                            let program = await XtreamAPI.shared.getCurrentProgram(streamId: id)
                            return (id, program)
                        }
                    }
                    for await (id, program) in group {
                        if let program {
                            epgCache[id] = program
                        }
                    }
                }

                // Update cards after each batch
                guard !Task.isCancelled else { return }
                notifyCardsOfEPGUpdate()
            }
        }
    }

    private func notifyCardsOfEPGUpdate() {
        Task { @MainActor in
            var count = 0
            func updateCards(in view: UIView) {
                if let card = view as? LiveTVCard {
                    card.updateEPG(from: epgCache)
                    count += 1
                }
                for sub in view.subviews { updateCards(in: sub) }
            }
            updateCards(in: self.view)
            if count > 0 {
                print("[LiveTV] Updated EPG on \(count) cards, cache has \(epgCache.count) entries")
            }
        }
    }

    // MARK: - Actions

    @objc private func searchTapped() {
        let alert = UIAlertController(title: "Search Channels", message: nil, preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "Channel name..."
            field.text = self.searchQuery
        }
        alert.addAction(UIAlertAction(title: "Search", style: .default) { [weak self] _ in
            self?.searchQuery = alert.textFields?.first?.text ?? ""
            self?.rebuildUI()
        })
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
            self?.searchQuery = ""
            self?.rebuildUI()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func playStream(_ stream: XtreamStream, title: String) {
        trackRecentChannel(stream.streamId)
        // Gather all visible streams for channel surfing
        let allVisible = categorySections.flatMap { $0.streams }
        let playerVC = LiveTVPlayerViewController(
            stream: stream, channels: allVisible,
            cleanName: { [weak self] s in self?.cleanChannelName(s.name) ?? s.name }
        )
        playerVC.onChannelChanged = { [weak self] s in self?.trackRecentChannel(s.streamId) }
        present(playerVC, animated: true)
    }

    private func toggleFavorite(streamId: Int) {
        var favs = favorites
        if favs.contains(streamId) { favs.remove(streamId) } else { favs.insert(streamId) }
        favorites = favs
    }

    private func trackRecentChannel(_ streamId: Int) {
        var recent = recentChannelIds
        recent.removeAll { $0 == streamId }
        recent.insert(streamId, at: 0)
        if recent.count > 15 { recent = Array(recent.prefix(15)) }
        recentChannelIds = recent
    }

    // MARK: - Name Cleaning

    private func cleanChannelName(_ name: String) -> String {
        var clean = name
        // Remove country prefix
        if let pipeRange = clean.range(of: "| ") {
            let prefix = String(clean[clean.startIndex..<pipeRange.lowerBound])
            if prefix.count <= 4 { clean = String(clean[pipeRange.upperBound...]) }
        }
        if let pipeRange = clean.range(of: "|") {
            let prefix = String(clean[clean.startIndex..<pipeRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            if prefix.count <= 4 && prefix == prefix.uppercased() {
                clean = String(clean[pipeRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        }
        // Strip quality suffixes
        let suffixes = [" UHD", " FHD", " HD", " SD"]
        for suffix in suffixes {
            if clean.uppercased().hasSuffix(suffix) {
                clean = String(clean.dropLast(suffix.count))
            }
        }
        // Remove Unicode superscript junk
        let junkChars = CharacterSet(charactersIn: "ᴴᴰᴿᴬᵂ⁶⁰ᶠᵖˢᶜᶦᵗʸ")
        clean = String(clean.unicodeScalars.filter { !junkChars.contains($0) })
        clean = clean.trimmingCharacters(in: .whitespaces)
        while clean.hasSuffix("-") || clean.hasSuffix(" -") {
            clean = String(clean.dropLast()).trimmingCharacters(in: .whitespaces)
        }
        return titleCase(clean.isEmpty ? name : clean)
    }

    private func baseChannelName(_ name: String) -> String {
        var clean = name
        if let pipeRange = clean.range(of: "| ") {
            let prefix = String(clean[clean.startIndex..<pipeRange.lowerBound])
            if prefix.count <= 4 { clean = String(clean[pipeRange.upperBound...]) }
        }
        let tags = [" UHD/4K+", " UHD/4K", " UHD", " 4K+", " 4K", " FHD", " HD",
                    " SD", " WEST", " EAST", " PLUS", " (bk)", " (EVENT ONLY)", " N (ES)"]
        for tag in tags { clean = clean.replacingOccurrences(of: tag, with: "", options: .caseInsensitive) }
        let junkChars = CharacterSet(charactersIn: "ᴴᴰᴿᴬᵂ⁶⁰ᶠᵖˢᶜᶦᵗʸ")
        clean = String(clean.unicodeScalars.filter { !junkChars.contains($0) })
        clean = clean.trimmingCharacters(in: .whitespaces)
        while clean.hasSuffix("-") || clean.hasSuffix("/") {
            clean = String(clean.dropLast()).trimmingCharacters(in: .whitespaces)
        }
        return clean.isEmpty ? name : clean
    }

    private func titleCase(_ str: String) -> String {
        guard str == str.uppercased(), str.count > 3 else { return str }
        let acronyms: Set<String> = ["ESPN", "NBC", "CBS", "ABC", "FOX", "CNN", "MSNBC", "TNT",
                                      "TBS", "AMC", "BET", "MTV", "VH1", "USA", "HGTV", "NESN",
                                      "CNBC", "CSPAN", "BBC", "HBO", "MAX", "FX", "FXX", "SEC"]
        return str.split(separator: " ").map { word in
            let w = String(word)
            if w.count <= 3 || acronyms.contains(w) { return w }
            if w.count <= 4 && w.rangeOfCharacter(from: .decimalDigits) != nil { return w }
            return w.prefix(1).uppercased() + w.dropFirst().lowercased()
        }.joined(separator: " ")
    }
}

// MARK: - Live TV Card

