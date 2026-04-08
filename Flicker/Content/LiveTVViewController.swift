import UIKit

final class LiveTVViewController: UIViewController {

    private let searchBar = UITextField()
    private let categoryCollectionView: UICollectionView
    private let channelTableView = UITableView(frame: .zero, style: .plain)

    private var allCategories: [XtreamCategory] = []
    private var displayCategories: [CategoryItem] = [] // "Favorites", "All", then real categories
    private var allStreams: [XtreamStream] = []
    private var filteredGroups: [ChannelGroup] = []
    private var selectedCategoryIndex = 0
    private var searchQuery = ""

    /// Groups duplicate channels by cleaned base name
    struct ChannelGroup {
        let baseName: String
        let streams: [XtreamStream]
        let icon: String? // best available icon

        var primaryStream: XtreamStream { streams[0] }
        var hasVariants: Bool { streams.count > 1 }
    }

    private var favorites: Set<Int> {
        get {
            Set(UserDefaults.standard.array(forKey: "flickerFavoriteChannels") as? [Int] ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: "flickerFavoriteChannels")
        }
    }

    private var skeletonView: UIView?
    private var recentlyWatchedRow: UIView?
    private var recentlyWatchedStack: UIStackView?

    private var recentChannelIds: [Int] {
        get { UserDefaults.standard.array(forKey: "flickerRecentChannels") as? [Int] ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "flickerRecentChannels") }
    }

    // All streams cache for lookup by ID
    private var allStreamsCache: [Int: XtreamStream] = [:]

    // Virtual category items
    struct CategoryItem {
        let id: String
        let name: String
        let isSpecial: Bool // favorites, all

        static let favorites = CategoryItem(id: "__favorites__", name: "Favorites", isSpecial: true)
        static let all = CategoryItem(id: "__all__", name: "All Channels", isSpecial: true)
    }

    override init(nibName: String?, bundle: Bundle?) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        layout.minimumInteritemSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 24)
        categoryCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nibName, bundle: bundle)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupHeader()
        setupSearchBar()
        setupRecentlyWatched()
        setupCategoryBar()
        setupChannelTable()
        showSkeleton()
        loadCategories()
    }

    // MARK: - Setup

    private func setupHeader() {
        let label = UILabel()
        label.text = "Live TV"
        label.font = .systemFont(ofSize: 48, weight: .bold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        label.tag = 500
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.topAnchor, constant: 60),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 48)
        ])
    }

    private func setupSearchBar() {
        searchBar.placeholder = "Search channels..."
        searchBar.font = .systemFont(ofSize: 24)
        searchBar.textColor = .white
        searchBar.backgroundColor = UIColor(white: 0.12, alpha: 1)
        searchBar.layer.cornerRadius = 14
        searchBar.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 20, height: 0))
        searchBar.leftViewMode = .always
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.addTarget(self, action: #selector(searchChanged), for: .editingChanged)
        searchBar.tag = 502
        view.addSubview(searchBar)

        let header = view.viewWithTag(500)!
        NSLayoutConstraint.activate([
            searchBar.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -48),
            searchBar.widthAnchor.constraint(equalToConstant: 400),
            searchBar.heightAnchor.constraint(equalToConstant: 56)
        ])
    }

    private func setupRecentlyWatched() {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.isHidden = true
        container.tag = 503
        view.addSubview(container)

        let label = UILabel()
        label.text = "Recently Watched"
        label.font = .systemFont(ofSize: 26, weight: .bold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.clipsToBounds = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scroll)

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        recentlyWatchedStack = stack

        let header = view.viewWithTag(500)!
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 20),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 48),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            label.topAnchor.constraint(equalTo: container.topAnchor),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),

            scroll.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 12),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            scroll.heightAnchor.constraint(equalToConstant: 80),

            stack.topAnchor.constraint(equalTo: scroll.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.heightAnchor)
        ])

        recentlyWatchedRow = container
    }

    private func refreshRecentlyWatched() {
        guard let stack = recentlyWatchedStack, let container = recentlyWatchedRow else { return }
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let recentIds = recentChannelIds
        guard !recentIds.isEmpty else {
            container.isHidden = true
            return
        }

        for streamId in recentIds {
            guard let stream = allStreamsCache[streamId] else { continue }
            let btn = RecentChannelButton(stream: stream, cleanName: cleanChannelName(stream.name))
            btn.onSelect = { [weak self] in
                self?.playStream(stream, title: self?.cleanChannelName(stream.name) ?? stream.name)
            }
            stack.addArrangedSubview(btn)
        }

        container.isHidden = stack.arrangedSubviews.isEmpty
    }

    private func trackRecentChannel(_ streamId: Int) {
        var recent = recentChannelIds
        recent.removeAll { $0 == streamId }
        recent.insert(streamId, at: 0)
        if recent.count > 15 { recent = Array(recent.prefix(15)) }
        recentChannelIds = recent
    }

    private func setupCategoryBar() {
        categoryCollectionView.backgroundColor = .clear
        categoryCollectionView.showsHorizontalScrollIndicator = false
        categoryCollectionView.register(CategoryPillCell.self, forCellWithReuseIdentifier: "CategoryPill")
        categoryCollectionView.dataSource = self
        categoryCollectionView.delegate = self
        categoryCollectionView.translatesAutoresizingMaskIntoConstraints = false
        categoryCollectionView.tag = 501
        view.addSubview(categoryCollectionView)

        // Anchor below recently watched if visible, otherwise below header
        let recentRow = view.viewWithTag(503)!
        let header = view.viewWithTag(500)!

        let topToRecent = categoryCollectionView.topAnchor.constraint(equalTo: recentRow.bottomAnchor, constant: 20)
        topToRecent.priority = .defaultHigh
        let topToHeader = categoryCollectionView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 24)
        topToHeader.priority = .defaultLow

        NSLayoutConstraint.activate([
            topToRecent,
            topToHeader,
            categoryCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 48),
            categoryCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            categoryCollectionView.heightAnchor.constraint(equalToConstant: 70)
        ])
    }

    private func setupChannelTable() {
        channelTableView.backgroundColor = .clear
        channelTableView.register(XtreamChannelCell.self, forCellReuseIdentifier: "XtreamChannel")
        channelTableView.dataSource = self
        channelTableView.delegate = self
        channelTableView.rowHeight = 90
        channelTableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(channelTableView)

        let catBar = view.viewWithTag(501)!
        NSLayoutConstraint.activate([
            channelTableView.topAnchor.constraint(equalTo: catBar.bottomAnchor, constant: 16),
            channelTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            channelTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            channelTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - Skeleton

    private func showSkeleton() {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)

        let catBar = view.viewWithTag(501)!
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: catBar.bottomAnchor, constant: 16),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            container.heightAnchor.constraint(equalToConstant: 600)
        ])

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])

        for _ in 0..<6 {
            let row = ShimmerView()
            row.layer.cornerRadius = 12
            row.translatesAutoresizingMaskIntoConstraints = false
            row.heightAnchor.constraint(equalToConstant: 80).isActive = true
            stack.addArrangedSubview(row)
        }

        skeletonView = container
    }

    private func removeSkeleton() {
        guard let sv = skeletonView else { return }
        UIView.animate(withDuration: 0.3) { sv.alpha = 0 } completion: { _ in sv.removeFromSuperview() }
        skeletonView = nil
    }

    // MARK: - Data Loading

    private func loadCategories() {
        Task {
            do {
                allCategories = try await XtreamAPI.shared.getCategories()
                buildDisplayCategories()
                categoryCollectionView.reloadData()

                // Load all channels for the first real category or favorites
                if !favorites.isEmpty {
                    selectedCategoryIndex = 0 // Favorites
                    loadFavorites()
                } else if let first = allCategories.first {
                    selectedCategoryIndex = 2 // First real category (after Favorites + All)
                    loadStreams(categoryId: first.categoryId)
                }
            } catch {
                removeSkeleton()
                showError(error.localizedDescription)
            }
        }
    }

    private func buildDisplayCategories() {
        displayCategories = [CategoryItem.favorites, CategoryItem.all]
        // Clean up category names and filter US-relevant ones
        for cat in allCategories {
            let cleanName = cleanCategoryName(cat.categoryName)
            displayCategories.append(CategoryItem(id: cat.categoryId, name: cleanName, isSpecial: false))
        }
    }

    private func loadStreams(categoryId: String) {
        Task {
            do {
                allStreams = try await XtreamAPI.shared.getLiveStreams(categoryId: categoryId)
                cacheStreams(allStreams)
                removeSkeleton()
                applyFilter()
                refreshRecentlyWatched()
            } catch {
                removeSkeleton()
                showError(error.localizedDescription)
            }
        }
    }

    private func loadAllStreams() {
        Task {
            do {
                allStreams = try await XtreamAPI.shared.getLiveStreams()
                cacheStreams(allStreams)
                removeSkeleton()
                applyFilter()
                refreshRecentlyWatched()
            } catch {
                removeSkeleton()
                showError(error.localizedDescription)
            }
        }
    }

    private func loadFavorites() {
        Task {
            do {
                let all = try await XtreamAPI.shared.getLiveStreams()
                cacheStreams(all)
                let favIds = favorites
                allStreams = all.filter { favIds.contains($0.streamId) }
                removeSkeleton()
                applyFilter()
                refreshRecentlyWatched()
            } catch {
                removeSkeleton()
                showError(error.localizedDescription)
            }
        }
    }

    private func cacheStreams(_ streams: [XtreamStream]) {
        for stream in streams {
            allStreamsCache[stream.streamId] = stream
        }
    }

    // MARK: - Filtering & Grouping

    private func applyFilter() {
        var result = allStreams

        // Filter out separator rows (names like "##### ... #####")
        result = result.filter { !$0.name.hasPrefix("#") }

        // Apply search
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            result = result.filter { cleanChannelName($0.name).lowercased().contains(query) }
        }

        // Group by base name
        var groupDict: [String: [XtreamStream]] = [:]
        var groupOrder: [String] = []

        for stream in result {
            let base = baseChannelName(stream.name)
            if groupDict[base] == nil {
                groupOrder.append(base)
            }
            groupDict[base, default: []].append(stream)
        }

        filteredGroups = groupOrder.compactMap { base in
            guard let streams = groupDict[base] else { return nil }
            let icon = streams.first(where: { $0.streamIcon != nil })?.streamIcon
            return ChannelGroup(baseName: base, streams: streams, icon: icon)
        }

        channelTableView.reloadData()
    }

    /// Aggressive name cleaning to find the core channel identity for grouping
    private func baseChannelName(_ name: String) -> String {
        var clean = name

        // Remove country prefix
        if let pipeRange = clean.range(of: "| ") {
            let prefix = String(clean[clean.startIndex..<pipeRange.lowerBound])
            if prefix.count <= 4 {
                clean = String(clean[pipeRange.upperBound...])
            }
        }

        // Remove quality and regional tags
        let tags = [" UHD/4K+", " UHD/4K", " UHD", " 4K+", " 4K", " FHD", " HD",
                    " SD", " WEST", " EAST", " PLUS", " (bk)", " (EVENT ONLY)"]
        for tag in tags {
            clean = clean.replacingOccurrences(of: tag, with: "", options: .caseInsensitive)
        }

        // Remove Unicode superscript junk
        let junkChars = CharacterSet(charactersIn: "ᴴᴰᴿᴬᵂ⁶⁰ᶠᵖˢᶜᶦᵗʸ")
        clean = String(clean.unicodeScalars.filter { !junkChars.contains($0) })
        clean = clean.trimmingCharacters(in: .whitespaces)

        while clean.hasSuffix("-") || clean.hasSuffix("/") {
            clean = String(clean.dropLast()).trimmingCharacters(in: .whitespaces)
        }

        return clean.isEmpty ? name : clean
    }

    /// Gets the variant label for a stream (the quality/region suffix)
    private func variantLabel(for stream: XtreamStream) -> String {
        let base = baseChannelName(stream.name)
        let clean = cleanChannelName(stream.name)

        // Find the difference between clean name and base name
        var label = clean
        if clean.hasPrefix(base) {
            label = String(clean.dropFirst(base.count)).trimmingCharacters(in: .whitespaces)
        }

        if label.isEmpty {
            // Try to extract quality from original name
            let original = stream.name.uppercased()
            if original.contains("4K") || original.contains("UHD") { return "4K" }
            if original.contains("FHD") { return "FHD" }
            if original.contains("HD") { return "HD" }
            if original.contains("WEST") { return "West" }
            if original.contains("EAST") { return "East" }
            return "Default"
        }
        return label
    }

    @objc private func searchChanged() {
        searchQuery = searchBar.text ?? ""
        applyFilter()
    }

    // MARK: - Name Cleaning

    private func cleanChannelName(_ name: String) -> String {
        var clean = name

        // Remove country prefixes like "US| ", "UK| ", "CA| "
        if let pipeRange = clean.range(of: "| ") {
            let prefix = String(clean[clean.startIndex..<pipeRange.lowerBound])
            if prefix.count <= 4 {
                clean = String(clean[pipeRange.upperBound...])
            }
        }

        // Remove quality tags
        clean = clean.replacingOccurrences(of: " HD", with: "")
        clean = clean.replacingOccurrences(of: " FHD", with: "")
        clean = clean.replacingOccurrences(of: " SD", with: "")

        // Remove Unicode superscript junk
        let junkChars = CharacterSet(charactersIn: "ᴴᴰᴿᴬᵂ⁶⁰ᶠᵖˢᶜᶦᵗʸ")
        clean = String(clean.unicodeScalars.filter { !junkChars.contains($0) })

        // Trim whitespace
        clean = clean.trimmingCharacters(in: .whitespaces)

        // Remove trailing " -" or "- " artifacts
        while clean.hasSuffix("-") || clean.hasSuffix(" -") {
            clean = String(clean.dropLast()).trimmingCharacters(in: .whitespaces)
        }

        return clean.isEmpty ? name : clean
    }

    private func cleanCategoryName(_ name: String) -> String {
        var clean = name

        // Remove country prefix
        if let pipeRange = clean.range(of: "| ") {
            let prefix = String(clean[clean.startIndex..<pipeRange.lowerBound])
            if prefix.count <= 4 {
                clean = String(clean[pipeRange.upperBound...])
            }
        }

        // Remove Unicode superscript junk
        let junkChars = CharacterSet(charactersIn: "ᴴᴰᴿᴬᵂ⁶⁰ᶠᵖˢᶜᶦᵗʸ/")
        clean = String(clean.unicodeScalars.filter { !junkChars.contains($0) })
        clean = clean.trimmingCharacters(in: .whitespaces)

        return clean.isEmpty ? name : clean
    }

    // MARK: - Favorites

    private func toggleFavorite(streamId: Int) {
        var favs = favorites
        if favs.contains(streamId) {
            favs.remove(streamId)
        } else {
            favs.insert(streamId)
        }
        favorites = favs

        // If viewing favorites, reload
        if selectedCategoryIndex == 0 {
            loadFavorites()
        } else {
            channelTableView.reloadData()
        }
    }

    // MARK: - Error

    private func showError(_ message: String) {
        let label = UILabel()
        label.text = message
        label.font = .systemFont(ofSize: 28, weight: .medium)
        label.textColor = UIColor(red: 1, green: 0.4, blue: 0.4, alpha: 1)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -100)
        ])
    }
}

// MARK: - Category Collection

extension LiveTVViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        displayCategories.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CategoryPill", for: indexPath) as! CategoryPillCell
        let cat = displayCategories[indexPath.item]
        let icon: String? = cat.id == "__favorites__" ? "star.fill" : nil
        cell.configure(title: cat.name, isSelected: indexPath.item == selectedCategoryIndex, icon: icon)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedCategoryIndex = indexPath.item
        categoryCollectionView.reloadData()

        let cat = displayCategories[indexPath.item]
        if cat.id == "__favorites__" {
            loadFavorites()
        } else if cat.id == "__all__" {
            loadAllStreams()
        } else {
            loadStreams(categoryId: cat.id)
        }
    }
}

// MARK: - Channel Table

extension LiveTVViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredGroups.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "XtreamChannel", for: indexPath) as! XtreamChannelCell
        let group = filteredGroups[indexPath.row]
        let stream = group.primaryStream
        let isFav = favorites.contains(stream.streamId)
        cell.configure(with: stream, cleanName: group.baseName, isFavorite: isFav, variantCount: group.streams.count)
        cell.onFavoriteToggle = { [weak self] in
            self?.toggleFavorite(streamId: stream.streamId)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let group = filteredGroups[indexPath.row]

        if group.hasVariants {
            showVariantPicker(for: group)
        } else {
            playStream(group.primaryStream, title: group.baseName)
        }
    }

    private func showVariantPicker(for group: ChannelGroup) {
        let alert = UIAlertController(
            title: group.baseName,
            message: "\(group.streams.count) sources available",
            preferredStyle: .actionSheet
        )

        for stream in group.streams {
            let label = variantLabel(for: stream)
            alert.addAction(UIAlertAction(title: label, style: .default) { [weak self] _ in
                self?.playStream(stream, title: group.baseName)
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func playStream(_ stream: XtreamStream, title: String) {
        trackRecentChannel(stream.streamId)

        // Get the flat list of streams for channel surfing
        let channelList = filteredGroups.map { $0.primaryStream }

        let playerVC = LiveTVPlayerViewController(
            stream: stream,
            channels: channelList,
            cleanName: { [weak self] s in self?.cleanChannelName(s.name) ?? s.name }
        )
        playerVC.onChannelChanged = { [weak self] newStream in
            self?.trackRecentChannel(newStream.streamId)
        }
        present(playerVC, animated: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshRecentlyWatched()
    }
}

// MARK: - Category Pill Cell

final class CategoryPillCell: UICollectionViewCell {

    private let label = UILabel()
    private let iconView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 25
        contentView.clipsToBounds = true

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 16)
        iconView.tintColor = .white
        iconView.isHidden = true
        stack.addArrangedSubview(iconView)

        label.font = .systemFont(ofSize: 22, weight: .semibold)
        label.textAlignment = .center
        stack.addArrangedSubview(label)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -20),
            contentView.widthAnchor.constraint(greaterThanOrEqualToConstant: 100)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, isSelected: Bool, icon: String? = nil) {
        label.text = title
        label.textColor = isSelected ? .white : .gray

        if let icon {
            iconView.image = UIImage(systemName: icon)
            iconView.isHidden = false
            iconView.tintColor = isSelected ? UIColor(red: 1, green: 0.84, blue: 0, alpha: 1) : .gray
        } else {
            iconView.isHidden = true
        }

        contentView.backgroundColor = isSelected
            ? UIColor.white.withAlphaComponent(0.15)
            : UIColor(white: 0.1, alpha: 1)

        if isSelected {
            contentView.layer.borderWidth = 1.5
            contentView.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        } else {
            contentView.layer.borderWidth = 0
        }
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                self.transform = CGAffineTransform(scaleX: 1.08, y: 1.08)
            } else {
                self.transform = .identity
            }
        }, completion: nil)
    }
}

// MARK: - Channel Cell

final class XtreamChannelCell: UITableViewCell {

    var onFavoriteToggle: (() -> Void)?

    private let logoImageView = UIImageView()
    private let channelNameLabel = UILabel()
    private let nowPlayingLabel = UILabel()
    private let variantBadge = UILabel()
    private let favoriteIcon = UIImageView()
    private let liveIndicator = UIView()

    private var loadTask: Task<Void, Never>?
    private var epgTask: Task<Void, Never>?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        backgroundColor = .clear
        selectionStyle = .none

        logoImageView.contentMode = .scaleAspectFit
        logoImageView.clipsToBounds = true
        logoImageView.layer.cornerRadius = 8
        logoImageView.backgroundColor = UIColor(white: 0.12, alpha: 1)
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(logoImageView)

        channelNameLabel.font = .systemFont(ofSize: 26, weight: .semibold)
        channelNameLabel.textColor = .white
        channelNameLabel.translatesAutoresizingMaskIntoConstraints = false

        nowPlayingLabel.font = .systemFont(ofSize: 20, weight: .regular)
        nowPlayingLabel.textColor = UIColor(white: 0.5, alpha: 1)
        nowPlayingLabel.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [channelNameLabel, nowPlayingLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textStack)

        variantBadge.font = .systemFont(ofSize: 16, weight: .bold)
        variantBadge.textColor = UIColor(white: 0.8, alpha: 1)
        variantBadge.textAlignment = .center
        variantBadge.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        variantBadge.layer.cornerRadius = 10
        variantBadge.clipsToBounds = true
        variantBadge.isHidden = true
        variantBadge.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(variantBadge)

        favoriteIcon.image = UIImage(systemName: "star")
        favoriteIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 20)
        favoriteIcon.tintColor = UIColor(white: 0.3, alpha: 1)
        favoriteIcon.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(favoriteIcon)

        liveIndicator.backgroundColor = UIColor(red: 1, green: 0.3, blue: 0.3, alpha: 1)
        liveIndicator.layer.cornerRadius = 5
        liveIndicator.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(liveIndicator)

        NSLayoutConstraint.activate([
            logoImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            logoImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 60),
            logoImageView.heightAnchor.constraint(equalToConstant: 60),

            textStack.leadingAnchor.constraint(equalTo: logoImageView.trailingAnchor, constant: 20),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: variantBadge.leadingAnchor, constant: -12),

            variantBadge.trailingAnchor.constraint(equalTo: favoriteIcon.leadingAnchor, constant: -16),
            variantBadge.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            variantBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            variantBadge.heightAnchor.constraint(equalToConstant: 28),

            favoriteIcon.trailingAnchor.constraint(equalTo: liveIndicator.leadingAnchor, constant: -20),
            favoriteIcon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            liveIndicator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            liveIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            liveIndicator.widthAnchor.constraint(equalToConstant: 10),
            liveIndicator.heightAnchor.constraint(equalToConstant: 10)
        ])
    }

    func configure(with stream: XtreamStream, cleanName: String, isFavorite: Bool, variantCount: Int = 1) {
        channelNameLabel.text = cleanName
        nowPlayingLabel.text = nil

        if variantCount > 1 {
            variantBadge.text = "  \(variantCount) sources  "
            variantBadge.isHidden = false
        } else {
            variantBadge.isHidden = true
        }

        favoriteIcon.image = UIImage(systemName: isFavorite ? "star.fill" : "star")
        favoriteIcon.tintColor = isFavorite ? UIColor(red: 1, green: 0.84, blue: 0, alpha: 1) : UIColor(white: 0.3, alpha: 1)

        loadTask?.cancel()
        logoImageView.image = UIImage(systemName: "tv")
        logoImageView.tintColor = UIColor(white: 0.3, alpha: 1)
        if let iconStr = stream.streamIcon, let iconURL = URL(string: iconStr) {
            loadTask = Task {
                let image = await ImageLoader.shared.loadImage(from: iconURL)
                if !Task.isCancelled, let image {
                    logoImageView.image = image
                    logoImageView.tintColor = nil
                }
            }
        }

        // Load EPG
        epgTask?.cancel()
        epgTask = Task {
            let program = await XtreamAPI.shared.getCurrentProgram(streamId: stream.streamId)
            guard !Task.isCancelled else { return }
            if let program {
                var text = program.decodedTitle
                if let mins = program.minutesRemaining {
                    text += " · \(mins)m left"
                }
                nowPlayingLabel.text = text
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        loadTask?.cancel()
        epgTask?.cancel()
        logoImageView.image = UIImage(systemName: "tv")
        nowPlayingLabel.text = nil
        variantBadge.isHidden = true
        onFavoriteToggle = nil
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations({
            self.contentView.backgroundColor = self.isFocused ? UIColor.white.withAlphaComponent(0.1) : .clear
            self.contentView.layer.cornerRadius = 12
        }, completion: nil)
    }

    // Long press on select to toggle favorite
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        // Play/pause button toggles favorite
        for press in presses {
            if press.type == .playPause {
                onFavoriteToggle?()
                return
            }
        }
        super.pressesBegan(presses, with: event)
    }
}

// MARK: - Recent Channel Button

final class RecentChannelButton: UIButton {

    var onSelect: (() -> Void)?

    private let logoImageView = UIImageView()
    private let nameLabel = UILabel()
    private var loadTask: Task<Void, Never>?

    init(stream: XtreamStream, cleanName: String) {
        super.init(frame: .zero)

        backgroundColor = UIColor(white: 0.12, alpha: 1)
        layer.cornerRadius = 12
        clipsToBounds = true

        logoImageView.contentMode = .scaleAspectFit
        logoImageView.clipsToBounds = true
        logoImageView.layer.cornerRadius = 6
        logoImageView.tintColor = UIColor(white: 0.3, alpha: 1)
        logoImageView.image = UIImage(systemName: "tv")
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(logoImageView)

        nameLabel.text = cleanName
        nameLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        nameLabel.textColor = .white
        nameLabel.numberOfLines = 1
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nameLabel)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 220),
            heightAnchor.constraint(equalToConstant: 70),

            logoImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            logoImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 44),
            logoImageView.heightAnchor.constraint(equalToConstant: 44),

            nameLabel.leadingAnchor.constraint(equalTo: logoImageView.trailingAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        if let iconStr = stream.streamIcon, let iconURL = URL(string: iconStr) {
            loadTask = Task {
                let image = await ImageLoader.shared.loadImage(from: iconURL)
                if !Task.isCancelled, let image {
                    logoImageView.image = image
                    logoImageView.tintColor = nil
                }
            }
        }

        addTarget(self, action: #selector(tapped), for: .primaryActionTriggered)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func tapped() {
        onSelect?()
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                self.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                self.backgroundColor = UIColor.white.withAlphaComponent(0.15)
            } else {
                self.transform = .identity
                self.backgroundColor = UIColor(white: 0.12, alpha: 1)
            }
        }, completion: nil)
    }
}
