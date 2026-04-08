import UIKit

enum RemoteStreamQuality: Int, CaseIterable {
    case maximum = 0     // Full quality remux (local only, will buffer remote)
    case high = 1        // 1080p 20 Mbps
    case medium = 2      // 1080p 8 Mbps
    case low = 3         // 720p 4 Mbps

    var title: String {
        switch self {
        case .maximum: return "Maximum (Original)"
        case .high: return "High (1080p 20 Mbps)"
        case .medium: return "Medium (1080p 8 Mbps)"
        case .low: return "Low (720p 4 Mbps)"
        }
    }

    var subtitle: String {
        switch self {
        case .maximum: return "Full 4K Blu-ray. May buffer on slow connections."
        case .high: return "Great quality. Works on most connections."
        case .medium: return "Good quality. Reliable streaming."
        case .low: return "Lower quality. Best for slow connections."
        }
    }

    /// Max bitrate in bits per second
    var maxBitrate: Int {
        switch self {
        case .maximum: return 200_000_000
        case .high: return 20_000_000
        case .medium: return 8_000_000
        case .low: return 4_000_000
        }
    }

    /// Max video width for transcoding
    var maxWidth: Int? {
        switch self {
        case .maximum: return nil
        case .high: return 1920
        case .medium: return 1920
        case .low: return 1280
        }
    }

    static var current: RemoteStreamQuality {
        RemoteStreamQuality(rawValue: UserDefaults.standard.integer(forKey: "flickerRemoteQuality")) ?? .high
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: "flickerRemoteQuality")
    }
}

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
        titleLabel.font = .systemFont(ofSize: 48, weight: .bold)
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
                        ? UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1)
                        : UIColor(red: 1, green: 0.4, blue: 0.4, alpha: 1))

        if !JellyfinAPI.shared.isAuthenticated {
            let reconnectButton = UIButton(type: .system)
            reconnectButton.setTitle("Reconnect", for: .normal)
            reconnectButton.titleLabel?.font = .systemFont(ofSize: 28, weight: .bold)
            reconnectButton.tintColor = .white
            reconnectButton.backgroundColor = UIColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0)
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
                   color: UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1))

        let quality = RemoteStreamQuality.current
        let qualityButton = UIButton(type: .system)
        qualityButton.setTitle("  Remote Quality: \(quality.title)", for: .normal)
        qualityButton.titleLabel?.font = .systemFont(ofSize: 26, weight: .semibold)
        qualityButton.tintColor = .white
        qualityButton.contentHorizontalAlignment = .left
        qualityButton.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        qualityButton.layer.cornerRadius = 14
        qualityButton.contentEdgeInsets = UIEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
        qualityButton.addTarget(self, action: #selector(qualityTapped), for: .primaryActionTriggered)
        stackView.addArrangedSubview(qualityButton)

        let qualityDesc = UILabel()
        qualityDesc.text = quality.subtitle
        qualityDesc.font = .systemFont(ofSize: 20, weight: .regular)
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
        addInfoRow("Status", value: "Active", color: UIColor(red: 0.3, green: 0.8, blue: 0.3, alpha: 1))
    }

    private func addSectionHeader(_ title: String) {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.textColor = UIColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0)
        stackView.addArrangedSubview(label)
    }

    private func addInfoRow(_ label: String, value: String, color: UIColor = .white) {
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fill

        let keyLabel = UILabel()
        keyLabel.text = label
        keyLabel.font = .systemFont(ofSize: 26, weight: .medium)
        keyLabel.textColor = .gray
        keyLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 26, weight: .semibold)
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
