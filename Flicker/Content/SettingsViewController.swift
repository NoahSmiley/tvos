import UIKit

final class SettingsViewController: UIViewController {

    private let stackView = UIStackView()
    private let statusLabel = UILabel()

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
        let spacer = UIView()
        spacer.heightAnchor.constraint(equalToConstant: 40).isActive = true
        stackView.addArrangedSubview(spacer)

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

    @objc private func reconnectTapped() {
        Task {
            await JellyfinAPI.shared.autoLogin()
            // Rebuild UI
            stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
            setupUI()
        }
    }
}
