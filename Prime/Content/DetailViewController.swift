import UIKit

final class DetailViewController: UIViewController {

    private let item: JellyfinItem
    private let bgColor = UIColor(white: 0.04, alpha: 1)

    private let backdropImageView = UIImageView()
    private let bottomGradient = CAGradientLayer()
    private let leftGradient = CAGradientLayer()

    private let scrollView = UIScrollView()
    private let solidBackground = UIView()
    private let contentStack = UIStackView()

    private let logoImageView = UIImageView()
    private let titleLabel = UILabel()
    private let playButton = FocusableButton()
    private let listButton = FocusableButton()

    private var seasons: [JellyfinItem] = []
    private var selectedSeasonId: String?
    private var episodes: [JellyfinItem] = []
    private var seasonPillButtons: [SeasonPillButton] = []
    private var seasonPickerScroll: UIScrollView?
    private var episodesWrapper: UIView?
    private var episodesStack: UIStackView?

    private var castCollectionView: UICollectionView?
    private var castMembers: [(name: String, role: String?, id: String)] = []

    private let horizontalPad: CGFloat = 80

    init(item: JellyfinItem) {
        self.item = item
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = bgColor
        setupBackdrop()
        setupScrollView()
        buildContent()
        loadData()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let b = backdropImageView.bounds
        bottomGradient.frame = b
        leftGradient.frame = CGRect(x: 0, y: 0, width: b.width * 0.45, height: b.height)
    }

    // MARK: - Backdrop (fixed)

    private func setupBackdrop() {
        backdropImageView.contentMode = .scaleAspectFill
        backdropImageView.clipsToBounds = true
        backdropImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backdropImageView)

        NSLayoutConstraint.activate([
            backdropImageView.topAnchor.constraint(equalTo: view.topAnchor),
            backdropImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdropImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdropImageView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.75)
        ])

        let bg = bgColor.cgColor
        let clear = UIColor.clear.cgColor

        bottomGradient.colors = [clear, UIColor(white: 0.04, alpha: 0.2).cgColor, bg]
        bottomGradient.locations = [0.0, 0.7, 1.0]
        backdropImageView.layer.addSublayer(bottomGradient)

        leftGradient.colors = [UIColor.black.withAlphaComponent(0.15).cgColor, clear]
        leftGradient.startPoint = CGPoint(x: 0, y: 0.5)
        leftGradient.endPoint = CGPoint(x: 0.1, y: 0.5)
        backdropImageView.layer.addSublayer(leftGradient)

        let backdropId = item.seriesId ?? item.id
        let url = JellyfinAPI.shared.imageURL(itemId: backdropId, imageType: "Backdrop", maxWidth: 1920)
            ?? JellyfinAPI.shared.imageURL(itemId: item.id, imageType: "Backdrop", maxWidth: 1920)
        Task {
            backdropImageView.image = await ImageLoader.shared.loadImage(from: url)
        }
    }

    // MARK: - Scroll View

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

        // Solid background that covers everything below the hero area
        solidBackground.backgroundColor = bgColor
        solidBackground.clipsToBounds = false
        solidBackground.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(solidBackground)

        // Vignette gradient at top of solid background (fades from transparent to bgColor)
        let topVignette = CAGradientLayer()
        topVignette.colors = [UIColor.clear.cgColor, bgColor.cgColor]
        topVignette.locations = [0.0, 1.0]
        topVignette.frame = CGRect(x: 0, y: -120, width: 3000, height: 120)
        solidBackground.layer.addSublayer(topVignette)

        contentStack.axis = .vertical
        contentStack.spacing = 36
        contentStack.alignment = .leading
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: horizontalPad),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -horizontalPad),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -200),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -(horizontalPad * 2)),

            // Solid bg starts where the backdrop gradient ends and extends to the bottom
            solidBackground.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 700),
            solidBackground.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor),
            solidBackground.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor),
            solidBackground.bottomAnchor.constraint(equalTo: contentStack.bottomAnchor, constant: 200)
        ])
    }

    // MARK: - Content

    private func buildContent() {
        // Spacer to push content below backdrop
        let spacer = UIView()
        spacer.heightAnchor.constraint(equalToConstant: 450).isActive = true
        contentStack.addArrangedSubview(spacer)

        // Logo or title — scaleAspectFit but constrained so no empty space
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.clipsToBounds = true
        logoImageView.isHidden = true
        NSLayoutConstraint.activate([
            logoImageView.heightAnchor.constraint(equalToConstant: 120)
        ])
        contentStack.addArrangedSubview(logoImageView)

        titleLabel.text = item.seriesName ?? item.name
        titleLabel.font = .systemFont(ofSize: 50, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowRadius = 4
        titleLabel.layer.shadowOpacity = 0.7
        titleLabel.layer.shadowOffset = .zero
        contentStack.addArrangedSubview(titleLabel)

        // Meta row — compact
        let metaStack = UIStackView()
        metaStack.axis = .horizontal
        metaStack.spacing = 14
        metaStack.alignment = .center

        if let year = item.productionYear { addMeta(to: metaStack, text: "\(year)") }
        if let rating = item.officialRating { addMeta(to: metaStack, text: rating) }
        if let mins = item.runtimeMinutes { addMeta(to: metaStack, text: "\(mins) min") }
        if let score = item.communityRating {
            let s = UIStackView()
            s.axis = .horizontal; s.spacing = 4; s.alignment = .center
            let star = UIImageView(image: UIImage(systemName: "star.fill"))
            star.tintColor = UIColor(red: 1, green: 0.84, blue: 0, alpha: 1)
            star.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 16)
            s.addArrangedSubview(star)
            let l = UILabel()
            l.text = String(format: "%.1f", score)
            l.font = .systemFont(ofSize: 21, weight: .semibold)
            l.textColor = .white
            s.addArrangedSubview(l)
            metaStack.addArrangedSubview(s)
        }
        if let genres = item.genres?.prefix(3), !genres.isEmpty {
            addMeta(to: metaStack, text: genres.joined(separator: " · "))
        }

        contentStack.addArrangedSubview(metaStack)

        // Buttons — smaller
        let buttonStack = UIStackView()
        buttonStack.axis = .horizontal
        buttonStack.spacing = 14

        let playTitle = (item.userData?.playbackPositionTicks ?? 0) > 0 ? "Resume" : "Play"
        playButton.style(title: playTitle, icon: "play.fill", isPrimary: true)
        playButton.addTarget(self, action: #selector(playTapped), for: .primaryActionTriggered)
        buttonStack.addArrangedSubview(playButton)

        listButton.style(title: "My List", icon: "plus", isPrimary: false)
        buttonStack.addArrangedSubview(listButton)

        contentStack.addArrangedSubview(buttonStack)

        // Synopsis — 3 lines max, cleaner
        if let overview = item.overview, !overview.isEmpty {
            let synopsisLabel = UILabel()
            synopsisLabel.text = overview
            synopsisLabel.font = .systemFont(ofSize: 24, weight: .regular)
            synopsisLabel.textColor = UIColor(white: 0.6, alpha: 1)
            synopsisLabel.numberOfLines = 4

            let wrapper = UIView()
            wrapper.addSubview(synopsisLabel)
            synopsisLabel.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                synopsisLabel.topAnchor.constraint(equalTo: wrapper.topAnchor),
                synopsisLabel.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
                synopsisLabel.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
                synopsisLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 800)
            ])
            contentStack.addArrangedSubview(wrapper)
        }

        // Prepare cast data
        if let people = item.people {
            castMembers = people.filter { $0.type == "Actor" }.prefix(15).map { ($0.name, $0.role, $0.id) }
        }
        if castMembers.isEmpty, let people = item.people {
            castMembers = people.prefix(15).map { ($0.name, $0.role, $0.id) }
        }

        // For movies, add cast now. For series, cast goes after seasons/episodes (added in loadData).
        if item.type != "Series" && !castMembers.isEmpty {
            setupCastSection()
        }

        // Load logo
        let logoId = item.seriesId ?? item.id
        let logoURL = JellyfinAPI.shared.imageURL(itemId: logoId, imageType: "Logo", maxWidth: 800)
        Task {
            let logo = await ImageLoader.shared.loadImage(from: logoURL)
            if let logo {
                logoImageView.image = logo
                logoImageView.isHidden = false
                titleLabel.isHidden = true

                // Set width based on actual aspect ratio so view fits tightly (no centering gap)
                let aspect = logo.size.width / logo.size.height
                let targetWidth = min(120 * aspect, 450)
                logoImageView.widthAnchor.constraint(equalToConstant: targetWidth).isActive = true
            }
        }
    }

    private func addMeta(to stack: UIStackView, text: String) {
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: 21, weight: .medium)
        l.textColor = UIColor(white: 0.55, alpha: 1)
        stack.addArrangedSubview(l)
    }

    // MARK: - Cast (focusable cells so scrolling works)

    private func setupCastSection() {
        let wrapper = UIView()

        let title = UILabel()
        title.text = "Cast & Crew"
        title.font = .systemFont(ofSize: 28, weight: .semibold)
        title.textColor = .white
        title.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(title)

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 120, height: 160)
        layout.minimumInteritemSpacing = 20
        layout.minimumLineSpacing = 20

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.clipsToBounds = false
        cv.register(CastCell.self, forCellWithReuseIdentifier: "CastCell")
        cv.dataSource = self
        cv.delegate = self
        cv.tag = 999
        cv.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(cv)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: wrapper.topAnchor),
            title.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            cv.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 16),
            cv.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            cv.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            cv.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            cv.heightAnchor.constraint(equalToConstant: 180)
        ])

        castCollectionView = cv

        // Force full width
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(wrapper)
        wrapper.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
    }

    // MARK: - Data

    private func loadData() {
        if item.type == "Series" {
            // Show skeleton episodes while loading
            showEpisodeSkeletons()

            Task {
                do {
                    seasons = try await JellyfinAPI.shared.getSeasons(seriesId: item.id)
                    removeEpisodeSkeletons()
                    if !seasons.isEmpty {
                        setupSeasonPicker()
                        setupEpisodesSection()
                        selectSeason(seasons[0])
                    }
                    // Add cast after seasons/episodes for Series
                    if !castMembers.isEmpty {
                        setupCastSection()
                    }
                } catch {
                    removeEpisodeSkeletons()
                }
            }
        }
    }

    private var episodeSkeletonViews: [UIView] = []

    private func showEpisodeSkeletons() {
        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false

        let titleShimmer = ShimmerView.textSkeleton(width: 180, height: 26)
        wrapper.addSubview(titleShimmer)
        titleShimmer.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(stack)

        for _ in 0..<4 {
            let row = SkeletonEpisodeRowView()
            stack.addArrangedSubview(row)
        }

        NSLayoutConstraint.activate([
            titleShimmer.topAnchor.constraint(equalTo: wrapper.topAnchor),
            titleShimmer.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            stack.topAnchor.constraint(equalTo: titleShimmer.bottomAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor)
        ])

        contentStack.addArrangedSubview(wrapper)
        wrapper.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
        episodeSkeletonViews.append(wrapper)
    }

    private func removeEpisodeSkeletons() {
        UIView.animate(withDuration: 0.3) {
            for v in self.episodeSkeletonViews { v.alpha = 0 }
        } completion: { _ in
            for v in self.episodeSkeletonViews { v.removeFromSuperview() }
            self.episodeSkeletonViews.removeAll()
        }
    }

    // MARK: - Season Picker (capsule pills)

    private func setupSeasonPicker() {
        let wrapper = UIView()

        let label = UILabel()
        label.text = "Seasons"
        label.font = .systemFont(ofSize: 28, weight: .semibold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(label)

        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.clipsToBounds = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(scroll)
        seasonPickerScroll = scroll

        let pillStack = UIStackView()
        pillStack.axis = .horizontal
        pillStack.spacing = 12
        pillStack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(pillStack)

        for season in seasons {
            let pill = SeasonPillButton(season: season)
            pill.addTarget(self, action: #selector(seasonPillTapped(_:)), for: .primaryActionTriggered)
            pillStack.addArrangedSubview(pill)
            seasonPillButtons.append(pill)
        }

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: wrapper.topAnchor),
            label.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            scroll.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 16),
            scroll.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor),
            scroll.heightAnchor.constraint(equalToConstant: 60),
            pillStack.topAnchor.constraint(equalTo: scroll.topAnchor),
            pillStack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            pillStack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            pillStack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            pillStack.heightAnchor.constraint(equalTo: scroll.heightAnchor)
        ])

        wrapper.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(wrapper)
        wrapper.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
    }

    @objc private func seasonPillTapped(_ sender: SeasonPillButton) {
        guard let season = sender.season else { return }
        selectSeason(season)
    }

    private func selectSeason(_ season: JellyfinItem) {
        selectedSeasonId = season.id
        for pill in seasonPillButtons {
            pill.setSelectedState(pill.season?.id == season.id)
        }

        Task {
            do {
                episodes = try await JellyfinAPI.shared.getEpisodes(seriesId: item.id, seasonId: season.id)
                rebuildEpisodeRows()
            } catch {}
        }
    }

    // MARK: - Episodes Section

    private func setupEpisodesSection() {
        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = "Episodes"
        label.font = .systemFont(ofSize: 28, weight: .semibold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(label)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        wrapper.addSubview(stack)
        episodesStack = stack

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: wrapper.topAnchor),
            label.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            stack.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor)
        ])

        episodesWrapper = wrapper
        contentStack.addArrangedSubview(wrapper)
        wrapper.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true
    }

    private func rebuildEpisodeRows() {
        guard let stack = episodesStack else { return }
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for (index, episode) in episodes.enumerated() {
            let row = EpisodeRowView(episode: episode)
            row.onSelect = { [weak self] ep in
                self?.playEpisode(ep)
            }
            stack.addArrangedSubview(row)

            if index < episodes.count - 1 {
                let divider = UIView()
                divider.backgroundColor = UIColor.white.withAlphaComponent(0.08)
                divider.translatesAutoresizingMaskIntoConstraints = false
                divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
                stack.addArrangedSubview(divider)
            }
        }
    }

    private func playEpisode(_ episode: JellyfinItem) {
        guard let url = JellyfinAPI.shared.playbackURL(itemId: episode.id) else { return }
        let startTicks = episode.userData?.playbackPositionTicks ?? 0
        let displayTitle = "S\(episode.parentIndexNumber ?? 0)E\(episode.indexNumber ?? 0) - \(episode.name)"
        let playerVC = PlayerViewController(streamURL: url, itemId: episode.id, title: displayTitle, startPositionTicks: startTicks)
        playerVC.configureChapters(from: episode)

        // Find next episode
        if let idx = episodes.firstIndex(where: { $0.id == episode.id }), idx + 1 < episodes.count {
            let next = episodes[idx + 1]
            playerVC.setNextEpisode(next)
            playerVC.onPlayNextEpisode = { [weak self] nextEp in
                self?.playEpisode(nextEp)
            }
        }

        present(playerVC, animated: true)
    }

    // MARK: - Actions

    @objc private func playTapped() {
        guard let url = JellyfinAPI.shared.playbackURL(itemId: item.id) else { return }
        let playerVC = PlayerViewController(
            streamURL: url, itemId: item.id,
            title: item.seriesName ?? item.name,
            startPositionTicks: item.userData?.playbackPositionTicks ?? 0
        )
        playerVC.configureChapters(from: item)
        present(playerVC, animated: true)
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        return [playButton]
    }

}

// MARK: - Collection View (Cast only)

extension DetailViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return castMembers.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CastCell", for: indexPath) as! CastCell
        let member = castMembers[indexPath.item]
        cell.configure(name: member.name, role: member.role, personId: member.id)
        return cell
    }
}

// MARK: - Cast Cell (focusable)

final class CastCell: UICollectionViewCell {
    private let imageView = UIImageView()
    private let nameLabel = UILabel()
    private let roleLabel = UILabel()
    private var loadTask: Task<Void, Never>?

    override init(frame: CGRect) {
        super.init(frame: frame)

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 45
        imageView.backgroundColor = UIColor(white: 0.12, alpha: 1)
        imageView.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
        imageView.layer.borderWidth = 1.5
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)

        nameLabel.font = .systemFont(ofSize: 18, weight: .medium)
        nameLabel.textColor = .white
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 2
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        roleLabel.font = .systemFont(ofSize: 15, weight: .regular)
        roleLabel.textColor = UIColor(white: 0.4, alpha: 1)
        roleLabel.textAlignment = .center
        roleLabel.numberOfLines = 1
        roleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(roleLabel)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 90),
            imageView.heightAnchor.constraint(equalToConstant: 90),
            nameLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 6),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            roleLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 1),
            roleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            roleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(name: String, role: String?, personId: String) {
        nameLabel.text = name
        roleLabel.text = role
        loadTask?.cancel()
        let url = JellyfinAPI.shared.imageURL(itemId: personId, imageType: "Primary", maxWidth: 200)
        loadTask = Task {
            let img = await ImageLoader.shared.loadImage(from: url)
            if !Task.isCancelled { imageView.image = img }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        loadTask?.cancel()
        imageView.image = nil
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                self.imageView.layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
            } else {
                self.transform = .identity
                self.imageView.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
            }
        }, completion: nil)
    }
}

// MARK: - Season Pill Button

final class SeasonPillButton: UIButton {

    let season: JellyfinItem?

    init(season: JellyfinItem) {
        self.season = season
        super.init(frame: .zero)

        setTitle(season.name, for: .normal)
        titleLabel?.font = .systemFont(ofSize: 22, weight: .medium)
        contentEdgeInsets = UIEdgeInsets(top: 10, left: 24, bottom: 10, right: 24)
        layer.cornerRadius = 22

        setSelectedState(false)
    }

    required init?(coder: NSCoder) { fatalError() }

    func setSelectedState(_ selected: Bool) {
        if selected {
            backgroundColor = .white
            setTitleColor(.black, for: .normal)
            setTitleColor(.black, for: .focused)
            titleLabel?.font = .systemFont(ofSize: 22, weight: .bold)
            layer.borderWidth = 0
        } else {
            backgroundColor = UIColor.white.withAlphaComponent(0.15)
            setTitleColor(UIColor(white: 0.75, alpha: 1), for: .normal)
            setTitleColor(.white, for: .focused)
            titleLabel?.font = .systemFont(ofSize: 22, weight: .medium)
            layer.borderWidth = 1
            layer.borderColor = UIColor.white.withAlphaComponent(0.25).cgColor
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

// MARK: - Episode Row View (focusable)

final class EpisodeRowView: UIView {

    var onSelect: ((JellyfinItem) -> Void)?

    private let episode: JellyfinItem
    private let thumbImageView = UIImageView()
    private let badgeLabel = UILabel()
    private let epTitleLabel = UILabel()
    private let durationLabel = UILabel()
    private let overviewLabel = UILabel()
    private let progressBar = UIView()
    private let progressFill = UIView()
    private var progressWidthConstraint: NSLayoutConstraint?
    private let bgView = UIView()

    private var loadTask: Task<Void, Never>?

    private let thumbWidth: CGFloat = 300
    private let thumbHeight: CGFloat = 169

    init(episode: JellyfinItem) {
        self.episode = episode
        super.init(frame: .zero)
        setupViews()
        configure()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var canBecomeFocused: Bool { true }

    private func setupViews() {
        bgView.backgroundColor = .clear
        bgView.layer.cornerRadius = 12
        bgView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bgView)

        // Thumbnail
        thumbImageView.contentMode = .scaleAspectFill
        thumbImageView.clipsToBounds = true
        thumbImageView.layer.cornerRadius = 8
        thumbImageView.backgroundColor = UIColor(white: 0.12, alpha: 1)
        thumbImageView.translatesAutoresizingMaskIntoConstraints = false
        bgView.addSubview(thumbImageView)

        // Progress bar on thumbnail
        progressBar.backgroundColor = UIColor(white: 0.3, alpha: 1)
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.isHidden = true
        thumbImageView.addSubview(progressBar)

        progressFill.backgroundColor = UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1)
        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressBar.addSubview(progressFill)

        let pw = progressFill.widthAnchor.constraint(equalToConstant: 0)
        progressWidthConstraint = pw

        // Episode badge (white pill with "E#")
        let badgeContainer = UIView()
        badgeContainer.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        badgeContainer.layer.cornerRadius = 6
        badgeContainer.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.setContentHuggingPriority(.required, for: .horizontal)
        badgeContainer.setContentCompressionResistancePriority(.required, for: .horizontal)

        badgeLabel.font = .systemFont(ofSize: 20, weight: .bold)
        badgeLabel.textColor = .black
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.setContentHuggingPriority(.required, for: .horizontal)
        badgeContainer.addSubview(badgeLabel)

        // Title
        epTitleLabel.font = .systemFont(ofSize: 27, weight: .semibold)
        epTitleLabel.textColor = .white
        epTitleLabel.numberOfLines = 1
        epTitleLabel.lineBreakMode = .byTruncatingTail
        epTitleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        epTitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // Duration
        durationLabel.font = .systemFont(ofSize: 20, weight: .regular)
        durationLabel.textColor = UIColor(white: 0.45, alpha: 1)
        durationLabel.setContentHuggingPriority(.required, for: .horizontal)
        durationLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        // Title row: badge + title + duration
        let titleRow = UIStackView(arrangedSubviews: [badgeContainer, epTitleLabel, durationLabel])
        titleRow.axis = .horizontal
        titleRow.spacing = 12
        titleRow.alignment = .center
        titleRow.distribution = .fill
        titleRow.translatesAutoresizingMaskIntoConstraints = false

        // Overview
        overviewLabel.font = .systemFont(ofSize: 20, weight: .regular)
        overviewLabel.textColor = UIColor(white: 0.5, alpha: 1)
        overviewLabel.numberOfLines = 2
        overviewLabel.translatesAutoresizingMaskIntoConstraints = false

        // Text stack
        let textStack = UIStackView(arrangedSubviews: [titleRow, overviewLabel])
        textStack.axis = .vertical
        textStack.spacing = 8
        textStack.translatesAutoresizingMaskIntoConstraints = false
        bgView.addSubview(textStack)

        NSLayoutConstraint.activate([
            bgView.topAnchor.constraint(equalTo: topAnchor),
            bgView.leadingAnchor.constraint(equalTo: leadingAnchor),
            bgView.trailingAnchor.constraint(equalTo: trailingAnchor),
            bgView.bottomAnchor.constraint(equalTo: bottomAnchor),

            thumbImageView.leadingAnchor.constraint(equalTo: bgView.leadingAnchor, constant: 16),
            thumbImageView.topAnchor.constraint(equalTo: bgView.topAnchor, constant: 16),
            thumbImageView.bottomAnchor.constraint(equalTo: bgView.bottomAnchor, constant: -16),
            thumbImageView.widthAnchor.constraint(equalToConstant: thumbWidth),
            thumbImageView.heightAnchor.constraint(equalToConstant: thumbHeight),

            progressBar.bottomAnchor.constraint(equalTo: thumbImageView.bottomAnchor),
            progressBar.leadingAnchor.constraint(equalTo: thumbImageView.leadingAnchor, constant: 6),
            progressBar.trailingAnchor.constraint(equalTo: thumbImageView.trailingAnchor, constant: -6),
            progressBar.heightAnchor.constraint(equalToConstant: 4),
            progressFill.topAnchor.constraint(equalTo: progressBar.topAnchor),
            progressFill.leadingAnchor.constraint(equalTo: progressBar.leadingAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressBar.bottomAnchor),
            pw,

            badgeLabel.topAnchor.constraint(equalTo: badgeContainer.topAnchor, constant: 4),
            badgeLabel.bottomAnchor.constraint(equalTo: badgeContainer.bottomAnchor, constant: -4),
            badgeLabel.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 10),
            badgeLabel.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -10),

            textStack.leadingAnchor.constraint(equalTo: thumbImageView.trailingAnchor, constant: 24),
            textStack.trailingAnchor.constraint(equalTo: bgView.trailingAnchor, constant: -16),
            textStack.centerYAnchor.constraint(equalTo: bgView.centerYAnchor)
        ])
    }

    private func configure() {
        if let num = episode.indexNumber {
            badgeLabel.text = "E\(num)"
        }
        epTitleLabel.text = episode.name

        if let ticks = episode.runTimeTicks {
            let totalMinutes = Int(ticks / 600_000_000)
            let hours = totalMinutes / 60
            let mins = totalMinutes % 60
            durationLabel.text = hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
        }

        overviewLabel.text = episode.overview

        if let percentage = episode.userData?.playedPercentage, percentage > 0, percentage < 100 {
            progressBar.isHidden = false
            layoutIfNeeded()
            progressWidthConstraint?.constant = (thumbWidth - 12) * CGFloat(percentage / 100.0)
        }

        loadTask = Task {
            let url = episode.primaryImageURL ?? episode.backdropImageURL
            let image = await ImageLoader.shared.loadImage(from: url)
            if !Task.isCancelled { thumbImageView.image = image }
        }
    }

    // MARK: - Focus

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                self.bgView.backgroundColor = UIColor.white.withAlphaComponent(0.12)
                self.transform = CGAffineTransform(scaleX: 1.02, y: 1.02)
            } else {
                self.bgView.backgroundColor = .clear
                self.transform = .identity
            }
        }, completion: nil)
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            if press.type == .select {
                onSelect?(episode)
                return
            }
        }
        super.pressesBegan(presses, with: event)
    }
}

// MARK: - Focusable Button (no tvOS system glow)

final class FocusableButton: UIButton {

    private var isPrimary = false
    private var normalBg: UIColor = .clear

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError() }

    func style(title: String, icon: String, isPrimary: Bool) {
        self.isPrimary = isPrimary

        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        setImage(UIImage(systemName: icon, withConfiguration: config), for: .normal)
        setTitle(" \(title)", for: .normal)
        titleLabel?.font = .systemFont(ofSize: 22, weight: .semibold)

        if isPrimary {
            normalBg = .white
            backgroundColor = .white
            tintColor = .black
            setTitleColor(.black, for: .normal)
            setTitleColor(.black, for: .focused)
        } else {
            normalBg = UIColor.white.withAlphaComponent(0.15)
            backgroundColor = normalBg
            tintColor = .white
            setTitleColor(.white, for: .normal)
            setTitleColor(.white, for: .focused)
        }

        layer.cornerRadius = 14
        contentEdgeInsets = UIEdgeInsets(top: 14, left: 30, bottom: 14, right: 30)
    }

    override var canBecomeFocused: Bool { true }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                self.transform = CGAffineTransform(scaleX: 1.08, y: 1.08)
                self.backgroundColor = self.isPrimary ? .white : UIColor.white.withAlphaComponent(0.3)
                self.layer.shadowColor = UIColor.white.cgColor
                self.layer.shadowOpacity = 0.3
                self.layer.shadowRadius = 10
                self.layer.shadowOffset = .zero
            } else {
                self.transform = .identity
                self.backgroundColor = self.normalBg
                self.layer.shadowOpacity = 0
            }
        }, completion: nil)
    }
}
