import UIKit

final class SurfChannelCard: UIButton {

    var onSelect: (() -> Void)?

    init(stream: XtreamStream, name: String, isCurrent: Bool) {
        super.init(frame: .zero)

        backgroundColor = isCurrent ? UIColor.white.withAlphaComponent(0.2) : UIColor(white: 0.15, alpha: 1)
        layer.cornerRadius = 10
        clipsToBounds = true

        if isCurrent {
            layer.borderWidth = 2
            layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        }

        let logo = UIImageView()
        logo.contentMode = .scaleAspectFit
        logo.tintColor = UIColor(white: 0.4, alpha: 1)
        logo.image = UIImage(systemName: "tv")
        logo.translatesAutoresizingMaskIntoConstraints = false
        addSubview(logo)

        let label = UILabel()
        label.text = name
        label.font = .systemFont(ofSize: 18, weight: isCurrent ? .bold : .medium)
        label.textColor = isCurrent ? .white : UIColor(white: 0.7, alpha: 1)
        label.numberOfLines = 2
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 150),
            heightAnchor.constraint(equalToConstant: 90),

            logo.centerXAnchor.constraint(equalTo: centerXAnchor),
            logo.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            logo.widthAnchor.constraint(equalToConstant: 32),
            logo.heightAnchor.constraint(equalToConstant: 32),

            label.topAnchor.constraint(equalTo: logo.bottomAnchor, constant: 4),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6)
        ])

        if let iconStr = stream.streamIcon, let iconURL = URL(string: iconStr) {
            Task {
                let image = await ImageLoader.shared.loadImage(from: iconURL)
                if let image {
                    logo.image = image
                    logo.tintColor = nil
                }
            }
        }

        addTarget(self, action: #selector(tapped), for: .primaryActionTriggered)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func tapped() { onSelect?() }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                self.backgroundColor = UIColor.white.withAlphaComponent(0.25)
            } else {
                self.transform = .identity
                self.backgroundColor = self.layer.borderWidth > 0
                    ? UIColor.white.withAlphaComponent(0.2)
                    : UIColor(white: 0.15, alpha: 1)
            }
        }, completion: nil)
    }
}
