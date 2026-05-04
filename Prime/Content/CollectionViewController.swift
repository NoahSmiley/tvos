import UIKit

final class CollectionViewController: UIViewController {

    private let item: JellyfinItem
    private let bgColor = AppTheme.background

    private let backdropImageView = UIImageView()
    private let bottomGradient = CAGradientLayer()
    private let tintOverlay = UIView()

    private let scrollView = UIScrollView()
    private let solidBackground = UIView()
    private let contentStack = UIStackView()

    private let logoImageView = UIImageView()
    private let titleLabel = UILabel()

    private var movies: [JellyfinItem] = []
    private var moviesStack: UIStackView?

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
        loadMovies()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let b = backdropImageView.bounds
        bottomGradient.frame = b
        tintOverlay.frame = b
    }

    // MARK: - Backdrop

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

        // Tint overlay for theming
        tintOverlay.alpha = 0.3
        backdropImageView.addSubview(tintOverlay)

        let bg = bgColor.cgColor
        let clear = UIColor.clear.cgColor
        bottomGradient.colors = [clear, UIColor(white: 0.04, alpha: 0.6).cgColor, bg]
        bottomGradient.locations = [0.0, 0.5, 1.0]
        backdropImageView.layer.addSublayer(bottomGradient)

        // Load backdrop
        let url = JellyfinAPI.shared.imageURL(itemId: item.id, imageType: "Backdrop", maxWidth: 1920)
        Task {
            let image = await ImageLoader.shared.loadImage(from: url)
            backdropImageView.image = image

            // Extract dominant color for theming
            if let color = image?.dominantColor {
                tintOverlay.backgroundColor = color
            }
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

        solidBackground.backgroundColor = bgColor
        solidBackground.clipsToBounds = false
        solidBackground.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(solidBackground)

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

            solidBackground.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 700),
            solidBackground.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor),
            solidBackground.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor),
            solidBackground.bottomAnchor.constraint(equalTo: contentStack.bottomAnchor, constant: 200)
        ])
    }

    // MARK: - Content

    private func buildContent() {
        // Spacer
        let spacer = UIView()
        spacer.heightAnchor.constraint(equalToConstant: 420).isActive = true
        contentStack.addArrangedSubview(spacer)

        // Logo or title
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.clipsToBounds = true
        logoImageView.isHidden = true
        logoImageView.heightAnchor.constraint(equalToConstant: 200).isActive = true
        contentStack.addArrangedSubview(logoImageView)

        titleLabel.text = item.name
        titleLabel.font = AppTheme.font(62, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowRadius = 4
        titleLabel.layer.shadowOpacity = 0.7
        titleLabel.layer.shadowOffset = .zero
        contentStack.addArrangedSubview(titleLabel)

        // Collection badge
        let badgeStack = UIStackView()
        badgeStack.axis = .horizontal
        badgeStack.spacing = 12
        badgeStack.alignment = .center

        let collectionIcon = UIImageView(image: UIImage(systemName: "rectangle.stack.fill"))
        collectionIcon.tintColor = AppTheme.textActive
        collectionIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 20)
        badgeStack.addArrangedSubview(collectionIcon)

        let badgeLabel = UILabel()
        badgeLabel.text = "Collection"
        badgeLabel.font = AppTheme.font(22, weight: .semibold)
        badgeLabel.textColor = AppTheme.textActive
        badgeStack.addArrangedSubview(badgeLabel)

        if let year = item.productionYear {
            let yearLabel = UILabel()
            yearLabel.text = "· \(year)"
            yearLabel.font = AppTheme.font(22, weight: .medium)
            yearLabel.textColor = UIColor(white: 0.5, alpha: 1)
            badgeStack.addArrangedSubview(yearLabel)
        }

        contentStack.addArrangedSubview(badgeStack)

        // Play All button — also serves as focus target above the movie grid
        let playButton = FocusableButton()
        playButton.style(title: "Play All", icon: "play.fill", isPrimary: true)
        playButton.addTarget(self, action: #selector(playAllTapped), for: .primaryActionTriggered)
        contentStack.addArrangedSubview(playButton)

        // Synopsis
        if let overview = item.overview, !overview.isEmpty {
            let synopsisLabel = UILabel()
            synopsisLabel.text = overview
            synopsisLabel.font = AppTheme.font(24)
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

        // Movies header
        let moviesHeader = UILabel()
        moviesHeader.text = "Movies"
        moviesHeader.font = AppTheme.font(32, weight: .bold)
        moviesHeader.textColor = .white
        contentStack.addArrangedSubview(moviesHeader)

        // Movies row — horizontal scroll with stack (no nested collection view focus trap)
        let movieScroll = UIScrollView()
        movieScroll.showsHorizontalScrollIndicator = false
        movieScroll.clipsToBounds = false
        movieScroll.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        movieScroll.addSubview(stack)
        moviesStack = stack

        let scrollWrapper = UIView()
        scrollWrapper.addSubview(movieScroll)
        scrollWrapper.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            movieScroll.topAnchor.constraint(equalTo: scrollWrapper.topAnchor),
            movieScroll.leadingAnchor.constraint(equalTo: scrollWrapper.leadingAnchor),
            movieScroll.trailingAnchor.constraint(equalTo: scrollWrapper.trailingAnchor),
            movieScroll.bottomAnchor.constraint(equalTo: scrollWrapper.bottomAnchor),
            movieScroll.heightAnchor.constraint(equalToConstant: 630),
            stack.topAnchor.constraint(equalTo: movieScroll.topAnchor),
            stack.leadingAnchor.constraint(equalTo: movieScroll.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: movieScroll.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: movieScroll.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: movieScroll.heightAnchor)
        ])

        contentStack.addArrangedSubview(scrollWrapper)
        scrollWrapper.widthAnchor.constraint(equalTo: contentStack.widthAnchor).isActive = true

        // Load logo
        let logoURL = JellyfinAPI.shared.imageURL(itemId: item.id, imageType: "Logo", maxWidth: 800)
        Task {
            let logo = await ImageLoader.shared.loadImage(from: logoURL)
            if let logo {
                logoImageView.image = logo
                logoImageView.isHidden = false
                titleLabel.isHidden = true

                let aspect = logo.size.width / logo.size.height
                let targetWidth = min(200 * aspect, 700)
                logoImageView.widthAnchor.constraint(equalToConstant: targetWidth).isActive = true
            }
        }
    }

    // MARK: - Data

    @objc private func playAllTapped() {
        guard let first = movies.first else { return }
        guard let url = JellyfinAPI.shared.playbackURL(itemId: first.id) else { return }
        let playerVC = PlayerViewController(
            streamURL: url, itemId: first.id,
            title: first.name,
            startPositionTicks: first.userData?.playbackPositionTicks ?? 0
        )
        present(playerVC, animated: true)
    }

    private func loadMovies() {
        Task {
            do {
                let response = try await JellyfinAPI.shared.getItems(
                    parentId: item.id,
                    sortBy: "SortName",
                    sortOrder: "Ascending",
                    limit: 50
                )
                movies = response.items
                buildMovieCards()
            } catch {
                print("[Collection] Failed to load movies: \(error)")
            }
        }
    }

    private func buildMovieCards() {
        guard let stack = moviesStack else { return }
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for movie in movies {
            let card = CollectionMovieCard(item: movie)
            card.onSelect = { [weak self] in
                if let rootVC = self?.parent as? RootViewController {
                    rootVC.showDetail(DetailViewController(item: movie))
                }
            }
            stack.addArrangedSubview(card)
        }
    }

}

// MARK: - Collection Movie Card (UIButton-based, no focus trap)

