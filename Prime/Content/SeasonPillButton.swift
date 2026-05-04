import UIKit

final class SeasonPillButton: UIButton {

    let season: JellyfinItem?

    init(season: JellyfinItem) {
        self.season = season
        super.init(frame: .zero)

        setTitle(season.name, for: .normal)
        titleLabel?.font = AppTheme.font(22, weight: .medium)
        contentEdgeInsets = UIEdgeInsets(top: 10, left: 24, bottom: 10, right: 24)
        layer.cornerRadius = 22

        setSelectedState(false)
    }

    required init?(coder: NSCoder) { fatalError() }

    func setSelectedState(_ selected: Bool) {
        if selected {
            backgroundColor = .white
            setTitleColor(.black, for: .normal)
            setTitleColor(.black, for: .focused)
            titleLabel?.font = AppTheme.font(22, weight: .bold)
            layer.borderWidth = 0
        } else {
            backgroundColor = UIColor.white.withAlphaComponent(0.15)
            setTitleColor(UIColor(white: 0.75, alpha: 1), for: .normal)
            setTitleColor(.white, for: .focused)
            titleLabel?.font = AppTheme.font(22, weight: .medium)
            layer.borderWidth = 1
            layer.borderColor = UIColor.white.withAlphaComponent(0.25).cgColor
        }
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                self.transform = CGAffineTransform(scaleX: 1.08, y: 1.08)
            } else {
                self.transform = .identity
            }
        }, completion: nil)
    }
}

// MARK: - Episode Row View (focusable)

