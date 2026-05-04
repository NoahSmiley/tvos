import UIKit


final class HeroBannerView: UIView {

    weak var delegate: HeroBannerDelegate?

    private let cardView = UIView()
    private let imageView = UIImageView()
    private let bottomGradient = CAGradientLayer()
    private let logoImageView = UIImageView()
    private let titleLabel = UILabel()
    private let watchButton = UIButton(type: .system)
    private let dotsStack = UIStackView()

    private var items: [JellyfinItem] = []
    private var currentIndex = 0
    private var cycleTimer: Timer?
    private var loadTask: Task<Void, Never>?

    // Card width drives height via 16:9 aspect ratio
    private let bgColor = AppTheme.background

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        cycleTimer?.invalidate()
    }

    // MARK: - Setup

    private func setupViews() {
        // Card container with rounded corners
        cardView.layer.cornerRadius = 0
        cardView.clipsToBounds = true
        cardView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cardView)

        // Backdrop image — top-aligned crop
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(imageView)

        // Bottom gradient
        let bg = bgColor.cgColor
        let clear = UIColor.clear.cgColor
        bottomGradient.colors = [clear, clear, UIColor(white: 0.04, alpha: 0.7).cgColor, bg]
        bottomGradient.locations = [0.0, 0.5, 0.8, 1.0]
        imageView.layer.addSublayer(bottomGradient)

        // Movie/show logo
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.clipsToBounds = true
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(logoImageView)

        // Fallback title
        titleLabel.font = AppTheme.font(48, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.isHidden = true
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleLabel)

        // Watch Now button
        let playImage = UIImage(systemName: "play.fill")
        watchButton.setImage(playImage, for: .normal)
        watchButton.setTitle("  Watch Now", for: .normal)
        watchButton.titleLabel?.font = AppTheme.font(24, weight: .bold)
        watchButton.tintColor = .white
        watchButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        watchButton.layer.cornerRadius = 10
        watchButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)
        watchButton.addTarget(self, action: #selector(watchTapped), for: .primaryActionTriggered)
        watchButton.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(watchButton)

        // Page dots
        dotsStack.axis = .horizontal
        dotsStack.spacing = 6
        dotsStack.alignment = .center
        dotsStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(dotsStack)

        NSLayoutConstraint.activate([
            // Card — edge to edge, fixed height
            cardView.topAnchor.constraint(equalTo: topAnchor),
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardView.heightAnchor.constraint(equalToConstant: 550),
            bottomAnchor.constraint(equalTo: cardView.bottomAnchor),

            // Image pinned to top, extends below card — card clips the bottom
            imageView.topAnchor.constraint(equalTo: cardView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            imageView.heightAnchor.constraint(equalTo: cardView.widthAnchor, multiplier: 9.0 / 16.0),

            // Logo
            logoImageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 40),
            logoImageView.bottomAnchor.constraint(equalTo: watchButton.topAnchor, constant: -20),
            logoImageView.widthAnchor.constraint(lessThanOrEqualToConstant: 400),
            logoImageView.heightAnchor.constraint(lessThanOrEqualToConstant: 130),

            // Fallback title
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 40),
            titleLabel.bottomAnchor.constraint(equalTo: watchButton.topAnchor, constant: -16),
            titleLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 600),

            // Watch button
            watchButton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 40),
            watchButton.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -32),

            // Page dots
            dotsStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -40),
            dotsStack.centerYAnchor.constraint(equalTo: watchButton.centerYAnchor)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        bottomGradient.frame = imageView.bounds
    }

    // MARK: - Data

    func setItems(_ items: [JellyfinItem]) {
        self.items = items
        guard !items.isEmpty else {
            isHidden = true
            return
        }

        isHidden = false
        buildDots()
        showItem(at: 0, animated: false)
        startTimer()
    }

    // MARK: - Display

    private func showItem(at index: Int, animated: Bool) {
        guard index < items.count else { return }
        currentIndex = index
        let item = items[index]

        updateDots()

        loadTask?.cancel()
        loadTask = Task {
            let backdropItemId = item.seriesId ?? item.id
            let backdropURL = JellyfinAPI.shared.imageURL(itemId: backdropItemId, imageType: "Backdrop", maxWidth: 1920)
                ?? JellyfinAPI.shared.imageURL(itemId: item.id, imageType: "Backdrop", maxWidth: 1920)

            let logoItemId = item.seriesId ?? item.id
            let logoURL = JellyfinAPI.shared.imageURL(itemId: logoItemId, imageType: "Logo", maxWidth: 1000)

            async let backdropResult = ImageLoader.shared.loadImage(from: backdropURL)
            async let logoResult = ImageLoader.shared.loadImage(from: logoURL)

            let backdrop = await backdropResult
            let logo = await logoResult

            guard !Task.isCancelled else { return }

            let applyChanges = {
                self.imageView.image = backdrop

                if let logo {
                    self.logoImageView.image = logo
                    self.logoImageView.isHidden = false
                    self.titleLabel.isHidden = true
                } else {
                    self.logoImageView.isHidden = true
                    self.titleLabel.text = item.seriesName ?? item.name
                    self.titleLabel.isHidden = false
                }
            }

            if animated {
                UIView.transition(with: self.cardView, duration: 0.8, options: .transitionCrossDissolve) {
                    applyChanges()
                }
            } else {
                applyChanges()
            }
        }
    }

    // MARK: - Actions

    @objc private func watchTapped() {
        guard currentIndex < items.count else { return }
        delegate?.heroBannerDidSelectItem(items[currentIndex])
    }

    // MARK: - Timer

    private func startTimer() {
        cycleTimer?.invalidate()
        guard items.count > 1 else { return }

        cycleTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { [weak self] _ in
            guard let self else { return }
            let next = (self.currentIndex + 1) % self.items.count
            self.showItem(at: next, animated: true)
        }
    }

    // MARK: - Page Dots

    private func buildDots() {
        dotsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for i in 0..<items.count {
            let dot = UIView()
            dot.layer.cornerRadius = 2
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.backgroundColor = .white
            dot.alpha = i == 0 ? 1.0 : 0.35

            let width: CGFloat = i == 0 ? 28 : 10
            dot.widthAnchor.constraint(equalToConstant: width).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 4).isActive = true

            dotsStack.addArrangedSubview(dot)
        }
    }

    private func updateDots() {
        for (i, dot) in dotsStack.arrangedSubviews.enumerated() {
            let isActive = i == currentIndex

            UIView.animate(withDuration: 0.3) {
                dot.alpha = isActive ? 1.0 : 0.35
            }

            for constraint in dot.constraints where constraint.firstAttribute == .width {
                constraint.constant = isActive ? 28 : 10
            }
        }

        UIView.animate(withDuration: 0.3) {
            self.dotsStack.layoutIfNeeded()
        }
    }
}
