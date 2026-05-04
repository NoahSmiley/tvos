import UIKit

final class PosterPickerCell: UICollectionViewCell {

    private let imageView = UIImageView()
    private let checkmark = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)

        checkmark.image = UIImage(systemName: "checkmark.circle.fill")
        checkmark.tintColor = AppTheme.textActive
        checkmark.translatesAutoresizingMaskIntoConstraints = false
        checkmark.isHidden = true
        contentView.addSubview(checkmark)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            checkmark.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            checkmark.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            checkmark.widthAnchor.constraint(equalToConstant: 32),
            checkmark.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(image: UIImage, isSelected: Bool) {
        imageView.image = image
        checkmark.isHidden = !isSelected
        contentView.layer.borderWidth = isSelected ? 3 : 0
        contentView.layer.borderColor = AppTheme.textActive.cgColor
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                self.transform = CGAffineTransform(scaleX: 1.12, y: 1.12)
                self.contentView.layer.shadowColor = UIColor.white.cgColor
                self.contentView.layer.shadowOpacity = 0.5
                self.contentView.layer.shadowRadius = 16
                self.contentView.layer.shadowOffset = .zero
            } else {
                self.transform = .identity
                self.contentView.layer.shadowOpacity = 0
            }
        }, completion: nil)
    }
}
