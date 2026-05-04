import UIKit

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
        liveBadge.font = AppTheme.font(13, weight: .bold)
        liveBadge.textColor = .white
        liveBadge.backgroundColor = AppTheme.liveRed
        liveBadge.layer.cornerRadius = 4
        liveBadge.clipsToBounds = true
        liveBadge.translatesAutoresizingMaskIntoConstraints = false
        addSubview(liveBadge)

        // Program title (hero text — shows what's on)
        programTitleLabel.text = cleanName // fallback to channel name until EPG loads
        programTitleLabel.font = AppTheme.font(22, weight: .bold)
        programTitleLabel.textColor = .white
        programTitleLabel.numberOfLines = 1
        programTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(programTitleLabel)

        // Program info (time | duration)
        programInfoLabel.font = AppTheme.font(16, weight: .medium)
        programInfoLabel.textColor = UIColor(white: 0.5, alpha: 1)
        programInfoLabel.numberOfLines = 1
        programInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(programInfoLabel)

        // Small channel name (only visible if EPG loaded, otherwise the title IS the channel name)
        channelNameLabel.text = cleanName
        channelNameLabel.font = AppTheme.font(15, weight: .medium)
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
                gradientLayer.colors = [darkColor.cgColor, AppTheme.background.cgColor]
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
