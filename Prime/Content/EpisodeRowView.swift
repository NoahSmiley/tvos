import UIKit

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

        progressFill.backgroundColor = AppTheme.textActive
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

        badgeLabel.font = AppTheme.font(20, weight: .bold)
        badgeLabel.textColor = .black
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.setContentHuggingPriority(.required, for: .horizontal)
        badgeContainer.addSubview(badgeLabel)

        // Title
        epTitleLabel.font = AppTheme.font(27, weight: .semibold)
        epTitleLabel.textColor = .white
        epTitleLabel.numberOfLines = 1
        epTitleLabel.lineBreakMode = .byTruncatingTail
        epTitleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        epTitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // Duration
        durationLabel.font = AppTheme.font(20)
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
        overviewLabel.font = AppTheme.font(20)
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

