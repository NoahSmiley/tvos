import UIKit

final class SidebarMenuButton: UIButton {

    let destination: SidebarDestination?

    private let iconView = UIImageView()
    private let titleLabel2 = UILabel()
    private var isItemSelected = false

    private var isCollapsed = false
    private var iconLeadingConstraint: NSLayoutConstraint!
    private var iconCenterXConstraint: NSLayoutConstraint!

    init(destination: SidebarDestination) {
        self.destination = destination
        super.init(frame: .zero)
        setupViews(destination: destination)
    }

    required init?(coder: NSCoder) {
        self.destination = nil
        super.init(coder: coder)
    }

    private func setupViews(destination: SidebarDestination) {
        backgroundColor = .clear
        layer.cornerRadius = 14
        clipsToBounds = false

        let config = UIImage.SymbolConfiguration(pointSize: 26, weight: .medium)
        iconView.image = UIImage(systemName: destination.iconName, withConfiguration: config)
        iconView.tintColor = UIColor(white: 0.45, alpha: 1)
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel2.text = destination.title
        titleLabel2.font = .systemFont(ofSize: 28, weight: .semibold)
        titleLabel2.textColor = UIColor(white: 0.45, alpha: 1)
        titleLabel2.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconView)
        addSubview(titleLabel2)

        iconLeadingConstraint = iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20)
        iconCenterXConstraint = iconView.centerXAnchor.constraint(equalTo: centerXAnchor)

        iconLeadingConstraint.isActive = true
        iconCenterXConstraint.isActive = false

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 64),

            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 36),
            iconView.heightAnchor.constraint(equalToConstant: 36),

            titleLabel2.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 16),
            titleLabel2.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel2.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16)
        ])
    }

    // MARK: - State

    func setSelected(_ selected: Bool, animated: Bool) {
        isItemSelected = selected
        let update = {
            self.iconView.tintColor = selected ? .white : UIColor(white: 0.45, alpha: 1)
            self.titleLabel2.textColor = selected ? .white : UIColor(white: 0.45, alpha: 1)
            self.backgroundColor = (selected && !self.isCollapsed) ? UIColor.white.withAlphaComponent(0.08) : .clear
        }

        if animated {
            UIView.animate(withDuration: 0.25, animations: update)
        } else {
            update()
        }
    }

    func setExpanded(_ expanded: Bool) {
        isCollapsed = !expanded
        titleLabel2.alpha = expanded ? 1 : 0
        iconLeadingConstraint.isActive = expanded
        iconCenterXConstraint.isActive = !expanded

        // Remove background highlight when collapsed
        if !expanded {
            backgroundColor = .clear
        } else if isItemSelected {
            backgroundColor = UIColor.white.withAlphaComponent(0.08)
        }
    }

    // MARK: - Focus

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                self.backgroundColor = UIColor.white.withAlphaComponent(0.15)
                self.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                self.iconView.tintColor = .white
                self.titleLabel2.textColor = .white
            } else {
                self.backgroundColor = (self.isItemSelected && !self.isCollapsed) ? UIColor.white.withAlphaComponent(0.08) : .clear
                self.transform = .identity
                self.iconView.tintColor = self.isItemSelected ? .white : UIColor(white: 0.45, alpha: 1)
                self.titleLabel2.textColor = self.isItemSelected ? .white : UIColor(white: 0.45, alpha: 1)
            }
        }, completion: nil)
    }

    override var canBecomeFocused: Bool { true }
}
