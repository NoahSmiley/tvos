import UIKit

final class SettingsViewController: UIViewController {

    private let stackView = UIStackView()
    private let statusLabel = UILabel()
    private var qualityValueLabel: UILabel?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupUI()
    }

    private func setupUI() {
        let titleLabel = UILabel()
        titleLabel.text = "Settings"
        titleLabel.font = AppTheme.font(48, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        stackView.axis = .vertical
        stackView.spacing = 24
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 60),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 48),
            stackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 40),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 48),
            stackView.widthAnchor.constraint(equalToConstant: 700)
        ])

        // Jellyfin Section
        addSectionHeader("Jellyfin Server")
        addInfoRow("Server", value: "jellyfin.athion.me")
        addInfoRow("User", value: "noah")
        addInfoRow("Status", value: JellyfinAPI.shared.isAuthenticated ? "Connected" : "Not Connected",
                    color: JellyfinAPI.shared.isAuthenticated
                        ? AppTheme.statusOk
                        : AppTheme.error)

        if !JellyfinAPI.shared.isAuthenticated {
            let reconnectButton = UIButton(type: .system)
            reconnectButton.setTitle("Reconnect", for: .normal)
            reconnectButton.titleLabel?.font = AppTheme.font(28, weight: .bold)
            reconnectButton.tintColor = .white
            reconnectButton.backgroundColor = AppTheme.textActive
            reconnectButton.layer.cornerRadius = 14
            reconnectButton.addTarget(self, action: #selector(reconnectTapped), for: .primaryActionTriggered)
            reconnectButton.heightAnchor.constraint(equalToConstant: 64).isActive = true
            stackView.addArrangedSubview(reconnectButton)
        }

        // Spacer
        let spacer1 = UIView()
        spacer1.heightAnchor.constraint(equalToConstant: 40).isActive = true
        stackView.addArrangedSubview(spacer1)

        // Playback Section
        addSectionHeader("Playback")

        addInfoRow("Local Network", value: "Full 4K (no transcode)",
                   color: AppTheme.statusOk)

        let quality = RemoteStreamQuality.current
        let qualityButton = UIButton(type: .system)
        qualityButton.setTitle("  Remote Quality: \(quality.title)", for: .normal)
        qualityButton.titleLabel?.font = AppTheme.font(26, weight: .semibold)
        qualityButton.tintColor = .white
        qualityButton.contentHorizontalAlignment = .left
        qualityButton.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        qualityButton.layer.cornerRadius = 14
        qualityButton.contentEdgeInsets = UIEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
        qualityButton.addTarget(self, action: #selector(qualityTapped), for: .primaryActionTriggered)
        stackView.addArrangedSubview(qualityButton)

        let qualityDesc = UILabel()
        qualityDesc.text = quality.subtitle
        qualityDesc.font = AppTheme.font(20)
        qualityDesc.textColor = UIColor(white: 0.5, alpha: 1)
        qualityDesc.numberOfLines = 0
        stackView.addArrangedSubview(qualityDesc)
        qualityValueLabel = qualityDesc

        // Spacer
        let spacer2 = UIView()
        spacer2.heightAnchor.constraint(equalToConstant: 40).isActive = true
        stackView.addArrangedSubview(spacer2)

        // IPTV Section
        addSectionHeader("IPTV (Xtream)")
        addInfoRow("Server", value: "line.trxdnscloud.ru")
        addInfoRow("Username", value: "914f80594b")
        addInfoRow("Status", value: "Active", color: AppTheme.statusOk)
    }

    private func addSectionHeader(_ title: String) {
        let label = UILabel()
        label.text = title
        label.font = AppTheme.font(32, weight: .bold)
        label.textColor = AppTheme.textActive
        stackView.addArrangedSubview(label)
    }

    private func addInfoRow(_ label: String, value: String, color: UIColor = .white) {
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fill

        let keyLabel = UILabel()
        keyLabel.text = label
        keyLabel.font = AppTheme.font(26, weight: .medium)
        keyLabel.textColor = .gray
        keyLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = AppTheme.font(26, weight: .semibold)
        valueLabel.textColor = color
        valueLabel.textAlignment = .right

        row.addArrangedSubview(keyLabel)
        row.addArrangedSubview(valueLabel)
        row.heightAnchor.constraint(equalToConstant: 44).isActive = true
        stackView.addArrangedSubview(row)
    }

    @objc private func qualityTapped() {
        let alert = UIAlertController(title: "Remote Streaming Quality", message: "Local network always streams at full 4K quality. This setting controls quality when streaming outside your home.", preferredStyle: .actionSheet)

        for quality in RemoteStreamQuality.allCases {
            let isCurrent = quality == RemoteStreamQuality.current
            let title = isCurrent ? "\(quality.title)  ✓" : quality.title
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                quality.save()
                self?.stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
                self?.setupUI()
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func reconnectTapped() {
        Task {
            await JellyfinAPI.shared.autoLogin()
            // Rebuild UI
            stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
            setupUI()
        }
    }
}
