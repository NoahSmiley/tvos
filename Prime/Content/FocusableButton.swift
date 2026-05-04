import UIKit

final class FocusableButton: UIButton {

    private var isPrimary = false
    private var normalBg: UIColor = .clear

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError() }

    func style(title: String, icon: String, isPrimary: Bool) {
        self.isPrimary = isPrimary

        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        setImage(UIImage(systemName: icon, withConfiguration: config), for: .normal)
        setTitle(" \(title)", for: .normal)
        titleLabel?.font = AppTheme.font(22, weight: .semibold)

        if isPrimary {
            normalBg = .white
            backgroundColor = .white
            tintColor = .black
            setTitleColor(.black, for: .normal)
            setTitleColor(.black, for: .focused)
        } else {
            normalBg = UIColor.white.withAlphaComponent(0.15)
            backgroundColor = normalBg
            tintColor = .white
            setTitleColor(.white, for: .normal)
            setTitleColor(.white, for: .focused)
        }

        layer.cornerRadius = 14
        contentEdgeInsets = UIEdgeInsets(top: 14, left: 30, bottom: 14, right: 30)
    }

    override var canBecomeFocused: Bool { true }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                self.transform = CGAffineTransform(scaleX: 1.08, y: 1.08)
                self.backgroundColor = self.isPrimary ? .white : UIColor.white.withAlphaComponent(0.3)
                self.layer.shadowColor = UIColor.white.cgColor
                self.layer.shadowOpacity = 0.3
                self.layer.shadowRadius = 10
                self.layer.shadowOffset = .zero
            } else {
                self.transform = .identity
                self.backgroundColor = self.normalBg
                self.layer.shadowOpacity = 0
            }
        }, completion: nil)
    }
}
