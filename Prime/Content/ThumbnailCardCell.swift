import UIKit

final class ThumbnailCardCell: UICollectionViewCell {

    private let thumbImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let progressBar = UIView()
    private let progressFill = UIView()
    private var progressWidthConstraint: NSLayoutConstraint?
    private var bottomGradientLayer: CAGradientLayer?

    private var loadTask: Task<Void, Never>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true
        contentView.backgroundColor = UIColor(white: 0.12, alpha: 1)

        // Thumbnail (16:9 top portion)
        thumbImageView.contentMode = .scaleAspectFill
        thumbImageView.clipsToBounds = true
        thumbImageView.backgroundColor = UIColor(white: 0.15, alpha: 1)
        thumbImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(thumbImageView)

        // Bottom gradient on thumbnail
        let gradientView = UIView()
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        gradientView.isUserInteractionEnabled = false
        contentView.addSubview(gradientView)

        let gradient = CAGradientLayer()
        gradient.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.7).cgColor]
        gradient.locations = [0.0, 1.0]
        gradientView.layer.addSublayer(gradient)
        bottomGradientLayer = gradient

        // Title (show name for episodes, movie name for movies)
        titleLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        // Subtitle (e.g. "S2:E5 Episode Title")
        subtitleLabel.font = .systemFont(ofSize: 18, weight: .regular)
        subtitleLabel.textColor = UIColor(white: 0.55, alpha: 1)
        subtitleLabel.numberOfLines = 1
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitleLabel)

        // Progress bar
        progressBar.backgroundColor = UIColor(white: 0.15, alpha: 1)
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.isHidden = true
        contentView.addSubview(progressBar)

        progressFill.backgroundColor = UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1)
        progressFill.translatesAutoresizingMaskIntoConstraints = false
        progressBar.addSubview(progressFill)

        let pw = progressFill.widthAnchor.constraint(equalToConstant: 0)
        progressWidthConstraint = pw

        NSLayoutConstraint.activate([
            thumbImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            thumbImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thumbImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            thumbImageView.heightAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 9.0 / 16.0),

            gradientView.leadingAnchor.constraint(equalTo: thumbImageView.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: thumbImageView.trailingAnchor),
            gradientView.bottomAnchor.constraint(equalTo: thumbImageView.bottomAnchor),
            gradientView.heightAnchor.constraint(equalToConstant: 60),

            titleLabel.topAnchor.constraint(equalTo: thumbImageView.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),

            progressBar.bottomAnchor.constraint(equalTo: thumbImageView.bottomAnchor),
            progressBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            progressBar.heightAnchor.constraint(equalToConstant: 3),

            progressFill.topAnchor.constraint(equalTo: progressBar.topAnchor),
            progressFill.leadingAnchor.constraint(equalTo: progressBar.leadingAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressBar.bottomAnchor),
            pw
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        bottomGradientLayer?.frame = CGRect(x: 0, y: 0, width: contentView.bounds.width, height: 60)
    }

    func configure(with item: JellyfinItem) {
        if item.type == "Episode", let seriesName = item.seriesName {
            // Episode: show series name prominently, episode info below
            titleLabel.text = seriesName
            var epText = ""
            if let s = item.parentIndexNumber, let e = item.indexNumber {
                epText = "S\(s):E\(e) "
            }
            epText += item.name
            subtitleLabel.text = epText
        } else {
            // Movie or other: show name
            titleLabel.text = item.name
            subtitleLabel.text = nil
        }

        // Progress
        if let percentage = item.userData?.playedPercentage, percentage > 0 {
            progressBar.isHidden = false
            layoutIfNeeded()
            progressWidthConstraint?.constant = progressBar.bounds.width * CGFloat(percentage / 100.0)
        } else {
            progressBar.isHidden = true
        }

        // Load thumbnail — use backdrop for episodes (horizontal), fall back to primary
        loadTask?.cancel()
        thumbImageView.image = nil
        loadTask = Task {
            let url = item.backdropImageURL ?? item.primaryImageURL
            let image = await ImageLoader.shared.loadImage(from: url)
            if !Task.isCancelled {
                thumbImageView.image = image
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        loadTask?.cancel()
        thumbImageView.image = nil
        progressBar.isHidden = true
    }

    // MARK: - Focus

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                self.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                self.contentView.layer.shadowColor = UIColor.white.cgColor
                self.contentView.layer.shadowOpacity = 0.25
                self.contentView.layer.shadowRadius = 16
                self.contentView.layer.shadowOffset = .zero
            } else {
                self.transform = .identity
                self.contentView.layer.shadowOpacity = 0
            }
        }, completion: nil)
    }
}
