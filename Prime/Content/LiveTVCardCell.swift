import UIKit

final class LiveTVCardCell: UICollectionViewCell {

    private let logoImageView = UIImageView()
    private let nameLabel = UILabel()
    private let liveTag = UILabel()

    private var loadTask: Task<Void, Never>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        contentView.backgroundColor = UIColor(white: 0.12, alpha: 1)
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true

        logoImageView.contentMode = .scaleAspectFit
        logoImageView.clipsToBounds = true
        logoImageView.tintColor = .gray
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(logoImageView)

        nameLabel.font = AppTheme.font(22, weight: .semibold)
        nameLabel.textColor = .white
        nameLabel.numberOfLines = 2
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        liveTag.text = "LIVE"
        liveTag.font = AppTheme.font(14, weight: .bold)
        liveTag.textColor = .white
        liveTag.backgroundColor = AppTheme.liveRed
        liveTag.textAlignment = .center
        liveTag.layer.cornerRadius = 4
        liveTag.clipsToBounds = true
        liveTag.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(liveTag)

        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            logoImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            logoImageView.widthAnchor.constraint(equalToConstant: 80),
            logoImageView.heightAnchor.constraint(equalToConstant: 80),

            nameLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),

            liveTag.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            liveTag.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            liveTag.widthAnchor.constraint(equalToConstant: 42),
            liveTag.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    func configure(with stream: XtreamStream) {
        nameLabel.text = stream.name

        loadTask?.cancel()
        logoImageView.image = UIImage(systemName: "tv")
        if let iconStr = stream.streamIcon, let iconURL = URL(string: iconStr) {
            loadTask = Task {
                let image = await ImageLoader.shared.loadImage(from: iconURL)
                if !Task.isCancelled, let image {
                    logoImageView.image = image
                }
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        loadTask?.cancel()
        logoImageView.image = UIImage(systemName: "tv")
    }

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
