import UIKit

final class LiveTVViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let searchBar = UITextField()
    private let categoryCollectionView: UICollectionView
    private var channelGridStack: UIStackView? // rows of channel cards

    private var allCategories: [XtreamCategory] = []
    private var displayCategories: [CategoryItem] = []
    private var allStreams: [XtreamStream] = []
    private var filteredGroups: [ChannelGroup] = []
    private var selectedCategoryIndex = 0
    private var searchQuery = ""

    private var favorites: Set<Int> {
        get { Set(UserDefaults.standard.array(forKey: "flickerFavoriteChannels") as? [Int] ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: "flickerFavoriteChannels") }
    }

    private var recentChannelIds: [Int] {
        get { UserDefaults.standard.array(forKey: "flickerRecentChannels") as? [Int] ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "flickerRecentChannels") }
    }

    private var allStreamsCache: [Int: XtreamStream] = [:]
    private var skeletonView: UIView?
    private var recentRow: UIView?

    struct ChannelGroup {
        let baseName: String
        let streams: [XtreamStream]
        let icon: String?
        var primaryStream: XtreamStream { streams[0] }
        var hasVariants: Bool { streams.count > 1 }
    }

    struct CategoryItem {
        let id: String
        let name: String
        let isSpecial: Bool
        static let favorites = CategoryItem(id: "__favorites__", name: "Favorites", isSpecial: true)
        static let all = CategoryItem(id: "__all__", name: "All Channels", isSpecial: true)
    }

    override init(nibName: String?, bundle: Bundle?) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 220, height: 50)
        layout.minimumInteritemSpacing = 12
        categoryCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nibName, bundle: bundle)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupLayout()
        showSkeleton()
        loadCategories()
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
        contentStack.spacing = 32
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 50),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 48),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -48),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -60),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -96)
        ])

        // Header row: title + search
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
            titleLabel.leadingAnchor.constraint(equalTo: headerRow.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerRow.centerYAnchor),
            searchBar.trailingAnchor.constraint(equalTo: headerRow.trailingAnchor),
            searchBar.centerYAnchor.constraint(equalTo: headerRow.centerYAnchor),
            searchBar.widthAnchor.constraint(equalToConstant: 380),
            searchBar.heightAnchor.constraint(equalToConstant: 50)
        ])
        contentStack.addArrangedSubview(headerRow)

        // Recently watched placeholder
        let recentContainer = UIView()
        recentContainer.isHidden = true
        recentContainer.tag = 700
        contentStack.addArrangedSubview(recentContainer)
        recentRow = recentContainer

        // Category pills
        categoryCollectionView.backgroundColor = .clear
        categoryCollectionView.showsHorizontalScrollIndicator = false
        categoryCollectionView.register(CategoryPillCell.self, forCellWithReuseIdentifier: "CategoryPill")
        categoryCollectionView.dataSource = self
        categoryCollectionView.delegate = self
        categoryCollectionView.translatesAutoresizingMaskIntoConstraints = false
        categoryCollectionView.heightAnchor.constraint(equalToConstant: 65).isActive = true
        contentStack.addArrangedSubview(categoryCollectionView)
    }

    // MARK: - Skeleton

    private func showSkeleton() {
        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false

        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 24
        row.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(row)

        for _ in 0..<5 {
            let card = ShimmerView()
            card.layer.cornerRadius = 12
            card.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                card.widthAnchor.constraint(equalToConstant: 300),
                card.heightAnchor.constraint(equalToConstant: 260)
            ])
            row.addArrangedSubview(card)
        }

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: wrapper.topAnchor),
            row.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
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

    // MARK: - Recently Watched

    private func refreshRecentRow() {
        guard let container = recentRow else { return }
        container.subviews.forEach { $0.removeFromSuperview() }

        let recentIds = recentChannelIds
        guard !recentIds.isEmpty else { container.isHidden = true; return }

        let label = UILabel()
        label.text = "Recently Watched"
        label.font = .systemFont(ofSize: 28, weight: .bold)
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
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        for streamId in recentIds.prefix(10) {
            guard let stream = allStreamsCache[streamId] else { continue }
            let card = LiveTVCard(stream: stream, cleanName: cleanChannelName(stream.name), style: .small)
            card.onSelect = { [weak self] in
                self?.playStream(stream, title: self?.cleanChannelName(stream.name) ?? stream.name)
            }
            stack.addArrangedSubview(card)
        }

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scroll.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 16),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            scroll.heightAnchor.constraint(equalToConstant: 200),
            stack.topAnchor.constraint(equalTo: scroll.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.heightAnchor)
        ])

        container.isHidden = stack.arrangedSubviews.isEmpty
    }

    // MARK: - Data Loading

    private func loadCategories() {
        Task {
            do {
                allCategories = try await XtreamAPI.shared.getCategories()
                buildDisplayCategories()
                categoryCollectionView.reloadData()

                if !favorites.isEmpty {
                    selectedCategoryIndex = 0
                    loadFavorites()
                } else if let entIdx = displayCategories.firstIndex(where: {
                    $0.name.uppercased().contains("ENTERTAINMENT")
                }) {
                    selectedCategoryIndex = entIdx
                    loadStreams(categoryId: displayCategories[entIdx].id)
                } else if displayCategories.count > 2 {
                    selectedCategoryIndex = 2
                    loadStreams(categoryId: displayCategories[2].id)
                }
            } catch {
                removeSkeleton()
            }
        }
    }

    private func buildDisplayCategories() {
        displayCategories = [CategoryItem.favorites, CategoryItem.all]
        let usCategories = allCategories.filter { cat in
            let name = cat.categoryName.uppercased()
            return name.hasPrefix("US|") || name.hasPrefix("US |") || name.contains("4K")
        }
        for cat in usCategories {
            let cleanName = cleanCategoryName(cat.categoryName)
            guard !cleanName.isEmpty else { continue }
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
                refreshRecentRow()
            } catch { removeSkeleton() }
        }
    }

    private func loadAllStreams() {
        Task {
            do {
                allStreams = try await XtreamAPI.shared.getLiveStreams()
                cacheStreams(allStreams)
                removeSkeleton()
                applyFilter()
                refreshRecentRow()
            } catch { removeSkeleton() }
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
                refreshRecentRow()
            } catch { removeSkeleton() }
        }
    }

    private func cacheStreams(_ streams: [XtreamStream]) {
        for stream in streams { allStreamsCache[stream.streamId] = stream }
    }

    // MARK: - Filtering & Grouping

    private func applyFilter() {
        var result = allStreams
        // Filter junk and non-US channels
        let junkPatterns = ["#####", "NO SIGNAL", "NO EVENT", "EVENT ONLY", "OFF AIR",
                           "[OFFLINE]", "NOT AVAILABLE", "COMING SOON"]
        result = result.filter { stream in
            let upper = stream.name.uppercased()
            if junkPatterns.contains(where: { upper.contains($0) }) { return false }
            // For categories that mix regions, only keep US/4K prefixed or unprefixed channels
            if upper.contains("| ") || upper.contains("|") {
                let prefix = upper.components(separatedBy: "|").first?.trimmingCharacters(in: .whitespaces) ?? ""
                return prefix == "US" || prefix == "4K" || prefix.isEmpty
            }
            return true
        }

        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            result = result.filter { cleanChannelName($0.name).lowercased().contains(query) }
        }

        var groupDict: [String: [XtreamStream]] = [:]
        var groupOrder: [String] = []
        for stream in result {
            let base = baseChannelName(stream.name)
            if groupDict[base] == nil { groupOrder.append(base) }
            groupDict[base, default: []].append(stream)
        }

        filteredGroups = groupOrder.compactMap { base in
            guard let streams = groupDict[base] else { return nil }
            let icon = streams.first(where: { $0.streamIcon != nil })?.streamIcon
            return ChannelGroup(baseName: titleCase(base), streams: streams, icon: icon)
        }

        rebuildChannelGrid()
    }

    @objc private func searchChanged() {
        searchQuery = searchBar.text ?? ""
        applyFilter()
    }

    // MARK: - Channel Card Grid

    private func rebuildChannelGrid() {
        channelGridStack?.removeFromSuperview()

        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 24
        grid.translatesAutoresizingMaskIntoConstraints = false

        // Build horizontal rows of cards (5-6 per row for scrolling)
        let cardsPerBatch = 20
        var batchStart = 0

        while batchStart < filteredGroups.count {
            let batchEnd = min(batchStart + cardsPerBatch, filteredGroups.count)
            let batch = Array(filteredGroups[batchStart..<batchEnd])

            let scroll = UIScrollView()
            scroll.showsHorizontalScrollIndicator = false
            scroll.clipsToBounds = false
            scroll.translatesAutoresizingMaskIntoConstraints = false

            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 24
            row.translatesAutoresizingMaskIntoConstraints = false
            scroll.addSubview(row)

            for group in batch {
                let card = LiveTVCard(
                    stream: group.primaryStream,
                    cleanName: group.baseName,
                    style: .large,
                    variantCount: group.streams.count,
                    allStreamsCache: allStreamsCache
                )
                card.onSelect = { [weak self] in
                    if group.hasVariants {
                        self?.showVariantPicker(for: group)
                    } else {
                        self?.playStream(group.primaryStream, title: group.baseName)
                    }
                }
                card.onFavorite = { [weak self] in
                    self?.toggleFavorite(streamId: group.primaryStream.streamId)
                }
                row.addArrangedSubview(card)
            }

            NSLayoutConstraint.activate([
                scroll.heightAnchor.constraint(equalToConstant: 280),
                row.topAnchor.constraint(equalTo: scroll.topAnchor),
                row.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
                row.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
                row.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
                row.heightAnchor.constraint(equalTo: scroll.heightAnchor)
            ])

            grid.addArrangedSubview(scroll)
            batchStart = batchEnd
        }

        contentStack.addArrangedSubview(grid)
        channelGridStack = grid
    }

    // MARK: - Actions

    private func showVariantPicker(for group: ChannelGroup) {
        let alert = UIAlertController(title: group.baseName, message: "\(group.streams.count) sources", preferredStyle: .actionSheet)
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
        let channelList = filteredGroups.map { $0.primaryStream }
        let playerVC = LiveTVPlayerViewController(
            stream: stream, channels: channelList,
            cleanName: { [weak self] s in self?.cleanChannelName(s.name) ?? s.name }
        )
        playerVC.onChannelChanged = { [weak self] s in self?.trackRecentChannel(s.streamId) }
        present(playerVC, animated: true)
    }

    private func toggleFavorite(streamId: Int) {
        var favs = favorites
        if favs.contains(streamId) { favs.remove(streamId) } else { favs.insert(streamId) }
        favorites = favs
        if selectedCategoryIndex == 0 { loadFavorites() }
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
        let junkChars = CharacterSet(charactersIn: "ᴴᴰᴿᴬᵂ⁶⁰ᶠᵖˢᶜᶦᵗʸ")
        clean = String(clean.unicodeScalars.filter { !junkChars.contains($0) })
        clean = clean.trimmingCharacters(in: .whitespaces)
        while clean.hasSuffix("-") || clean.hasSuffix(" -") {
            clean = String(clean.dropLast()).trimmingCharacters(in: .whitespaces)
        }
        return titleCase(clean.isEmpty ? name : clean)
    }

    private func cleanCategoryName(_ name: String) -> String {
        var clean = name
        if let pipeRange = clean.range(of: "| ") {
            let prefix = String(clean[clean.startIndex..<pipeRange.lowerBound])
            if prefix.count <= 4 { clean = String(clean[pipeRange.upperBound...]) }
        }
        let junkChars = CharacterSet(charactersIn: "ᴴᴰᴿᴬᵂ⁶⁰ᶠᵖˢᶜᶦᵗʸ/")
        clean = String(clean.unicodeScalars.filter { !junkChars.contains($0) })
        clean = clean.trimmingCharacters(in: .whitespaces)
        return clean.isEmpty ? name : clean
    }

    private func baseChannelName(_ name: String) -> String {
        var clean = name
        if let pipeRange = clean.range(of: "| ") {
            let prefix = String(clean[clean.startIndex..<pipeRange.lowerBound])
            if prefix.count <= 4 { clean = String(clean[pipeRange.upperBound...]) }
        }
        let tags = [" UHD/4K+", " UHD/4K", " UHD", " 4K+", " 4K", " FHD", " HD",
                    " SD", " WEST", " EAST", " PLUS", " (bk)", " (EVENT ONLY)"]
        for tag in tags { clean = clean.replacingOccurrences(of: tag, with: "", options: .caseInsensitive) }
        let junkChars = CharacterSet(charactersIn: "ᴴᴰᴿᴬᵂ⁶⁰ᶠᵖˢᶜᶦᵗʸ")
        clean = String(clean.unicodeScalars.filter { !junkChars.contains($0) })
        clean = clean.trimmingCharacters(in: .whitespaces)
        while clean.hasSuffix("-") || clean.hasSuffix("/") {
            clean = String(clean.dropLast()).trimmingCharacters(in: .whitespaces)
        }
        return clean.isEmpty ? name : clean
    }

    private func variantLabel(for stream: XtreamStream) -> String {
        let original = stream.name.uppercased()
        if original.contains("4K") || original.contains("UHD") { return "4K" }
        if original.contains("FHD") { return "FHD" }
        if original.contains("WEST") { return "West" }
        if original.contains("EAST") { return "East" }
        if original.contains("PLUS") { return "Plus" }
        if original.contains("HD") { return "HD" }
        return "Default"
    }

    private func titleCase(_ str: String) -> String {
        guard str == str.uppercased(), str.count > 3 else { return str }
        let acronyms: Set<String> = ["ESPN", "NBC", "CBS", "ABC", "FOX", "CNN", "MSNBC", "TNT",
                                      "TBS", "AMC", "BET", "MTV", "VH1", "USA", "HGTV", "NESN",
                                      "CNBC", "CSPAN", "BBC", "HBO", "MAX", "FX", "FXX"]
        return str.split(separator: " ").map { word in
            let w = String(word)
            if w.count <= 3 || acronyms.contains(w) { return w }
            if w.count <= 4 && w.rangeOfCharacter(from: .decimalDigits) != nil { return w }
            return w.prefix(1).uppercased() + w.dropFirst().lowercased()
        }.joined(separator: " ")
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
        cell.configure(title: cat.name, isSelected: indexPath.item == selectedCategoryIndex,
                       icon: cat.id == "__favorites__" ? "star.fill" : nil)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedCategoryIndex = indexPath.item
        categoryCollectionView.reloadData()
        let cat = displayCategories[indexPath.item]
        if cat.id == "__favorites__" { loadFavorites() }
        else if cat.id == "__all__" { loadAllStreams() }
        else { loadStreams(categoryId: cat.id) }
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
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -16)
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
        } else { iconView.isHidden = true }
        contentView.backgroundColor = isSelected ? UIColor.white.withAlphaComponent(0.15) : UIColor(white: 0.1, alpha: 1)
        contentView.layer.borderWidth = isSelected ? 1.5 : 0
        contentView.layer.borderColor = isSelected ? UIColor.white.withAlphaComponent(0.3).cgColor : nil
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations({
            self.transform = self.isFocused ? CGAffineTransform(scaleX: 1.08, y: 1.08) : .identity
        }, completion: nil)
    }
}

// MARK: - Live TV Card (Fubo-style)

final class LiveTVCard: UIButton {

    var onSelect: (() -> Void)?
    var onFavorite: (() -> Void)?

    enum Style { case large, small }

    private let logoImageView = UIImageView()
    private let thumbnailView = UIView()
    private let liveBadge = UILabel()
    private let channelNameLabel = UILabel()
    private let programLabel = UILabel()
    private let variantBadge = UILabel()

    private var loadTask: Task<Void, Never>?
    private var epgTask: Task<Void, Never>?

    private let cardWidth: CGFloat
    private let cardHeight: CGFloat

    init(stream: XtreamStream, cleanName: String, style: Style, variantCount: Int = 1, allStreamsCache: [Int: XtreamStream]? = nil) {
        cardWidth = style == .large ? 300 : 200
        cardHeight = style == .large ? 260 : 180
        super.init(frame: .zero)

        backgroundColor = UIColor(white: 0.1, alpha: 1)
        layer.cornerRadius = 14
        clipsToBounds = true

        // Channel logo (top-left)
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.clipsToBounds = true
        logoImageView.tintColor = UIColor(white: 0.4, alpha: 1)
        logoImageView.image = UIImage(systemName: "tv")
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(logoImageView)

        // Thumbnail area (dark gradient placeholder)
        thumbnailView.backgroundColor = UIColor(white: 0.08, alpha: 1)
        thumbnailView.layer.cornerRadius = 8
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(thumbnailView)

        // LIVE badge
        liveBadge.text = " LIVE "
        liveBadge.font = .systemFont(ofSize: 13, weight: .heavy)
        liveBadge.textColor = .white
        liveBadge.backgroundColor = UIColor(red: 0.9, green: 0.15, blue: 0.15, alpha: 1)
        liveBadge.layer.cornerRadius = 4
        liveBadge.clipsToBounds = true
        liveBadge.translatesAutoresizingMaskIntoConstraints = false
        addSubview(liveBadge)

        // Channel name
        channelNameLabel.text = cleanName
        channelNameLabel.font = .systemFont(ofSize: style == .large ? 22 : 18, weight: .bold)
        channelNameLabel.textColor = .white
        channelNameLabel.numberOfLines = 1
        channelNameLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(channelNameLabel)

        // Program info
        programLabel.font = .systemFont(ofSize: style == .large ? 18 : 15, weight: .regular)
        programLabel.textColor = UIColor(white: 0.5, alpha: 1)
        programLabel.numberOfLines = 1
        programLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(programLabel)

        // Variant badge
        if variantCount > 1 {
            variantBadge.text = " \(variantCount) "
            variantBadge.font = .systemFont(ofSize: 13, weight: .bold)
            variantBadge.textColor = .white
            variantBadge.backgroundColor = UIColor.white.withAlphaComponent(0.2)
            variantBadge.layer.cornerRadius = 4
            variantBadge.clipsToBounds = true
            variantBadge.translatesAutoresizingMaskIntoConstraints = false
            addSubview(variantBadge)

            NSLayoutConstraint.activate([
                variantBadge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
                variantBadge.topAnchor.constraint(equalTo: topAnchor, constant: 12)
            ])
        }

        let thumbHeight: CGFloat = style == .large ? 150 : 100

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: cardWidth),
            heightAnchor.constraint(equalToConstant: cardHeight),

            logoImageView.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            logoImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            logoImageView.widthAnchor.constraint(equalToConstant: style == .large ? 48 : 32),
            logoImageView.heightAnchor.constraint(equalToConstant: style == .large ? 28 : 20),

            thumbnailView.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 10),
            thumbnailView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            thumbnailView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            thumbnailView.heightAnchor.constraint(equalToConstant: thumbHeight),

            liveBadge.leadingAnchor.constraint(equalTo: thumbnailView.leadingAnchor, constant: 8),
            liveBadge.bottomAnchor.constraint(equalTo: thumbnailView.bottomAnchor, constant: -8),

            channelNameLabel.topAnchor.constraint(equalTo: thumbnailView.bottomAnchor, constant: 8),
            channelNameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            channelNameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            programLabel.topAnchor.constraint(equalTo: channelNameLabel.bottomAnchor, constant: 2),
            programLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            programLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12)
        ])

        // Load logo
        let iconStr = stream.streamIcon ?? ""
        let isGenericIcon = iconStr.lowercased().contains("/4k.png")

        if isGenericIcon, let cache = allStreamsCache {
            let searchName = cleanName.uppercased()
            if let match = cache.values.first(where: { s in
                let n = s.name.uppercased()
                return n.contains(searchName) && !n.hasPrefix("4K|") && s.streamIcon != nil && !s.streamIcon!.lowercased().contains("/4k.png")
            }), let url = URL(string: match.streamIcon!) {
                loadTask = Task {
                    let img = await ImageLoader.shared.loadImage(from: url)
                    if !Task.isCancelled, let img { logoImageView.image = img; logoImageView.tintColor = nil }
                }
            }
        } else if !iconStr.isEmpty, let url = URL(string: iconStr) {
            loadTask = Task {
                let img = await ImageLoader.shared.loadImage(from: url)
                if !Task.isCancelled, let img { logoImageView.image = img; logoImageView.tintColor = nil }
            }
        }

        // Load EPG
        epgTask = Task {
            let program = await XtreamAPI.shared.getCurrentProgram(streamId: stream.streamId)
            guard !Task.isCancelled else { return }
            if let program {
                var text = program.decodedTitle
                if let mins = program.minutesRemaining { text += " · \(mins)m" }
                programLabel.text = text
            }
        }

        addTarget(self, action: #selector(tapped), for: .primaryActionTriggered)
    }

    required init?(coder: NSCoder) { fatalError() }

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
            } else {
                self.transform = .identity
                self.layer.shadowOpacity = 0
                self.layer.masksToBounds = true
            }
        }, completion: nil)
    }
}
