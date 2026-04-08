import UIKit

final class LiveTVViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let searchBar = UITextField()
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
        refreshRecentRow()
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
        titleLabel.font = .systemFont(ofSize: 48, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerRow.addSubview(titleLabel)

        searchBar.placeholder = "Search channels..."
        searchBar.font = .systemFont(ofSize: 22)
        searchBar.textColor = .white
        searchBar.backgroundColor = UIColor(white: 0.12, alpha: 1)
        searchBar.layer.cornerRadius = 14
        searchBar.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 20, height: 0))
        searchBar.leftViewMode = .always
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.addTarget(self, action: #selector(searchChanged), for: .editingChanged)
        headerRow.addSubview(searchBar)

        NSLayoutConstraint.activate([
            headerRow.heightAnchor.constraint(equalToConstant: 56),
            titleLabel.leadingAnchor.constraint(equalTo: headerRow.leadingAnchor, constant: 48),
            titleLabel.centerYAnchor.constraint(equalTo: headerRow.centerYAnchor),
            searchBar.trailingAnchor.constraint(equalTo: headerRow.trailingAnchor, constant: -48),
            searchBar.centerYAnchor.constraint(equalTo: headerRow.centerYAnchor),
            searchBar.widthAnchor.constraint(equalToConstant: 380),
            searchBar.heightAnchor.constraint(equalToConstant: 50)
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
                async let cats = XtreamAPI.shared.getCategories()
                async let streams = XtreamAPI.shared.getLiveStreams()

                let allCats = try await cats
                let allStreams = try await streams

                // Cache all streams
                for s in allStreams { allStreamsCache[s.streamId] = s }

                // Build sections by mapping categories to our named sections
                buildSections(categories: allCats, streams: allStreams)
                removeSkeleton()
                rebuildUI()
                refreshRecentRow()
                loadEPGForVisibleChannels()
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
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(label)

        let countLabel = UILabel()
        countLabel.text = "\(streams.count) channels"
        countLabel.font = .systemFont(ofSize: 20, weight: .regular)
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

    private func loadEPGForVisibleChannels() {
        epgLoadTask?.cancel()

        // Collect first 30 unique stream IDs across all sections for initial load
        var streamIds: [Int] = []
        for section in categorySections {
            for stream in section.streams {
                if streamIds.count >= 30 { break }
                if !streamIds.contains(stream.streamId) {
                    streamIds.append(stream.streamId)
                }
            }
            if streamIds.count >= 30 { break }
        }

        epgLoadTask = Task {
            // Process 5 at a time
            for batch in stride(from: 0, to: streamIds.count, by: 5) {
                guard !Task.isCancelled else { return }
                let end = min(batch + 5, streamIds.count)
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

                // Update cards on main thread after each batch
                guard !Task.isCancelled else { return }
                notifyCardsOfEPGUpdate()
            }
        }
    }

    private func notifyCardsOfEPGUpdate() {
        // Walk all cards and update any that have EPG data now
        func updateCards(in view: UIView) {
            if let card = view as? LiveTVCard {
                card.updateEPG(from: epgCache)
            }
            for sub in view.subviews { updateCards(in: sub) }
        }
        updateCards(in: contentStack)
    }

    // MARK: - Actions

    @objc private func searchChanged() {
        searchQuery = searchBar.text ?? ""
        rebuildUI()
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

final class LiveTVCard: UIButton {

    var onSelect: (() -> Void)?
    var onFavorite: (() -> Void)?

    let streamId: Int
    private let cleanName: String
    private let logoImageView = UIImageView()
    private let channelNameLabel = UILabel()
    private let programTitleLabel = UILabel()
    private let programInfoLabel = UILabel()
    private let liveBadge = UILabel()
    private var loadTask: Task<Void, Never>?

    private let gradientLayer = CAGradientLayer()

    init(stream: XtreamStream, cleanName: String, allStreamsCache: [Int: XtreamStream]) {
        self.streamId = stream.streamId
        self.cleanName = cleanName
        super.init(frame: .zero)

        backgroundColor = UIColor(white: 0.1, alpha: 1)
        layer.cornerRadius = 14
        clipsToBounds = true

        // Gradient background (updated when logo loads with dominant color)
        gradientLayer.colors = [UIColor(white: 0.15, alpha: 1).cgColor, UIColor(white: 0.06, alpha: 1).cgColor]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.cornerRadius = 14
        layer.insertSublayer(gradientLayer, at: 0)

        // Large logo as the visual content
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.clipsToBounds = true
        logoImageView.tintColor = UIColor(white: 0.25, alpha: 1)
        logoImageView.image = UIImage(systemName: "tv")
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(logoImageView)

        // LIVE badge
        liveBadge.text = " LIVE "
        liveBadge.font = .systemFont(ofSize: 13, weight: .heavy)
        liveBadge.textColor = .white
        liveBadge.backgroundColor = UIColor(red: 0.9, green: 0.15, blue: 0.15, alpha: 1)
        liveBadge.layer.cornerRadius = 4
        liveBadge.clipsToBounds = true
        liveBadge.translatesAutoresizingMaskIntoConstraints = false
        addSubview(liveBadge)

        // Program title (hero text — shows what's on)
        programTitleLabel.text = cleanName // fallback to channel name until EPG loads
        programTitleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        programTitleLabel.textColor = .white
        programTitleLabel.numberOfLines = 1
        programTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(programTitleLabel)

        // Program info (time | duration)
        programInfoLabel.font = .systemFont(ofSize: 16, weight: .medium)
        programInfoLabel.textColor = UIColor(white: 0.5, alpha: 1)
        programInfoLabel.numberOfLines = 1
        programInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(programInfoLabel)

        // Small channel name (only visible if EPG loaded, otherwise the title IS the channel name)
        channelNameLabel.text = cleanName
        channelNameLabel.font = .systemFont(ofSize: 15, weight: .medium)
        channelNameLabel.textColor = UIColor(white: 0.4, alpha: 1)
        channelNameLabel.numberOfLines = 1
        channelNameLabel.isHidden = true // hidden until EPG loads
        channelNameLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(channelNameLabel)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 280),
            heightAnchor.constraint(equalToConstant: 240),

            logoImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -30),
            logoImageView.widthAnchor.constraint(equalToConstant: 160),
            logoImageView.heightAnchor.constraint(equalToConstant: 100),

            liveBadge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            liveBadge.topAnchor.constraint(equalTo: topAnchor, constant: 12),

            programTitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            programTitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            programTitleLabel.bottomAnchor.constraint(equalTo: programInfoLabel.topAnchor, constant: -3),

            programInfoLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            programInfoLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            programInfoLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),

            channelNameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            channelNameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12)
        ])

        // Load logo
        let iconStr = stream.streamIcon ?? ""
        let isGenericIcon = iconStr.lowercased().contains("/4k.png")

        if isGenericIcon {
            let searchName = cleanName.uppercased()
            if let match = allStreamsCache.values.first(where: { s in
                let n = s.name.uppercased()
                return n.contains(searchName) && !n.hasPrefix("4K|") && s.streamIcon != nil && !s.streamIcon!.lowercased().contains("/4k.png")
            }), let url = URL(string: match.streamIcon!) {
                loadLogo(url)
            }
        } else if !iconStr.isEmpty, let url = URL(string: iconStr) {
            loadLogo(url)
        }

        addTarget(self, action: #selector(tapped), for: .primaryActionTriggered)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func loadLogo(_ url: URL) {
        loadTask = Task {
            let img = await ImageLoader.shared.loadImage(from: url)
            if !Task.isCancelled, let img {
                // Check if image is very dark — if so, use it as template to render white
                if img.isDark {
                    logoImageView.image = img.withRenderingMode(.alwaysTemplate)
                    logoImageView.tintColor = .white
                } else {
                    logoImageView.image = img
                    logoImageView.tintColor = nil
                }

                // Extract dominant color for gradient background
                let color = img.dominantColor ?? UIColor(white: 0.15, alpha: 1)
                let darkColor = color.withAlphaComponent(0.4)
                gradientLayer.colors = [darkColor.cgColor, UIColor(white: 0.04, alpha: 1).cgColor]
            }
        }
    }

    /// Called by the VC after batch EPG load completes
    func updateEPG(from cache: [Int: XtreamEPGEntry]) {
        guard let program = cache[streamId] else { return }

        // Show the program name as the hero title
        programTitleLabel.text = program.decodedTitle
        channelNameLabel.isHidden = false

        // Build info line
        var infoParts: [String] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")
        if let startDate = formatter.date(from: program.start) {
            let displayFmt = DateFormatter()
            displayFmt.dateFormat = "h:mma"
            displayFmt.amSymbol = "am"
            displayFmt.pmSymbol = "pm"
            infoParts.append(displayFmt.string(from: startDate))
        }
        if let mins = program.minutesRemaining {
            infoParts.append("\(mins)m left")
        }
        programInfoLabel.text = infoParts.joined(separator: " | ")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    @objc private func tapped() { onSelect?() }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            if press.type == .playPause { onFavorite?(); return }
        }
        super.pressesBegan(presses, with: event)
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                self.transform = CGAffineTransform(scaleX: 1.06, y: 1.06)
                self.layer.shadowColor = UIColor.white.cgColor
                self.layer.shadowOpacity = 0.2
                self.layer.shadowRadius = 16
                self.layer.shadowOffset = .zero
                self.layer.masksToBounds = false
                self.backgroundColor = UIColor(white: 0.14, alpha: 1)
            } else {
                self.transform = .identity
                self.layer.shadowOpacity = 0
                self.layer.masksToBounds = true
                self.backgroundColor = UIColor(white: 0.1, alpha: 1)
            }
        }, completion: nil)
    }
}
