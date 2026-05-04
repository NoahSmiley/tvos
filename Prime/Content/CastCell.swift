import UIKit

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

        nameLabel.font = AppTheme.font(18, weight: .medium)
        nameLabel.textColor = .white
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 2
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        roleLabel.font = AppTheme.font(15)
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

