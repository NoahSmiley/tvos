import UIKit

final class EpisodeCell: UITableViewCell {

    private let thumbImageView = UIImageView()
    private let epTitleLabel = UILabel()
    private let epNumberLabel = UILabel()
    private let epOverviewLabel = UILabel()

    private var loadTask: Task<Void, Never>?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        backgroundColor = .clear
        selectionStyle = .none

        thumbImageView.contentMode = .scaleAspectFill
        thumbImageView.clipsToBounds = true
        thumbImageView.layer.cornerRadius = 10
        thumbImageView.backgroundColor = UIColor(white: 0.15, alpha: 1)
        thumbImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(thumbImageView)

        epNumberLabel.font = AppTheme.font(20, weight: .bold)
        epNumberLabel.textColor = AppTheme.textActive
        epNumberLabel.translatesAutoresizingMaskIntoConstraints = false

        epTitleLabel.font = AppTheme.font(26, weight: .semibold)
        epTitleLabel.textColor = .white
        epTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        epOverviewLabel.font = AppTheme.font(20)
        epOverviewLabel.textColor = .gray
        epOverviewLabel.numberOfLines = 2
        epOverviewLabel.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [epNumberLabel, epTitleLabel, epOverviewLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textStack)

        NSLayoutConstraint.activate([
            thumbImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            thumbImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            thumbImageView.widthAnchor.constraint(equalToConstant: 180),
            thumbImageView.heightAnchor.constraint(equalToConstant: 100),

            textStack.leadingAnchor.constraint(equalTo: thumbImageView.trailingAnchor, constant: 20),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    func configure(with episode: JellyfinItem) {
        epNumberLabel.text = "Episode \(episode.indexNumber ?? 0)"
        epTitleLabel.text = episode.name
        epOverviewLabel.text = episode.overview

        loadTask?.cancel()
        thumbImageView.image = nil
        loadTask = Task {
            let image = await ImageLoader.shared.loadImage(from: episode.primaryImageURL)
            if !Task.isCancelled { thumbImageView.image = image }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        loadTask?.cancel()
        thumbImageView.image = nil
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations({
            self.contentView.backgroundColor = self.isFocused ? UIColor.white.withAlphaComponent(0.1) : .clear
            self.contentView.layer.cornerRadius = 12
        }, completion: nil)
    }
}
