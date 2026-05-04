import UIKit


final class SidebarViewController: UIViewController {

    weak var delegate: SidebarDelegate?

    private let stackView = UIStackView()
    private let collapseButton = UIButton(type: .system)
    private(set) var menuButtons: [SidebarMenuButton] = []

    private var isExpanded = true
    private(set) var selectedDestination: SidebarDestination = .home

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.background
        setupMenu()
        setupCollapseButton()
        selectDestination(.home, animated: false)
    }

    // MARK: - Setup

    private func setupMenu() {
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.alignment = .fill

        let mainDestinations: [SidebarDestination] = [.search, .home, .movies, .tvShows, .liveTV]
        let bottomDestinations: [SidebarDestination] = [.settings]

        for dest in mainDestinations {
            let button = SidebarMenuButton(destination: dest)
            button.addTarget(self, action: #selector(menuButtonTapped(_:)), for: .primaryActionTriggered)
            stackView.addArrangedSubview(button)
            menuButtons.append(button)
        }

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        stackView.addArrangedSubview(spacer)

        for dest in bottomDestinations {
            let button = SidebarMenuButton(destination: dest)
            button.addTarget(self, action: #selector(menuButtonTapped(_:)), for: .primaryActionTriggered)
            stackView.addArrangedSubview(button)
            menuButtons.append(button)
        }

        view.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 50),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -120)
        ])
    }

    private func setupCollapseButton() {
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        collapseButton.setImage(UIImage(systemName: "sidebar.left", withConfiguration: config), for: .normal)
        collapseButton.tintColor = .gray
        collapseButton.addTarget(self, action: #selector(collapseButtonTapped), for: .primaryActionTriggered)

        view.addSubview(collapseButton)
        collapseButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collapseButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -40),
            collapseButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            collapseButton.widthAnchor.constraint(equalToConstant: 56),
            collapseButton.heightAnchor.constraint(equalToConstant: 56)
        ])
    }

    // MARK: - Actions

    @objc private func menuButtonTapped(_ sender: SidebarMenuButton) {
        guard let dest = sender.destination else { return }
        selectDestination(dest, animated: true)
        delegate?.sidebarDidSelectDestination(dest)
    }

    @objc private func collapseButtonTapped() {
        delegate?.sidebarDidRequestToggle()
    }

    // MARK: - Selection

    func selectDestination(_ destination: SidebarDestination, animated: Bool) {
        selectedDestination = destination
        for button in menuButtons {
            button.setSelected(button.destination == destination, animated: animated)
        }
    }

    var selectedButton: SidebarMenuButton? {
        menuButtons.first { $0.destination == selectedDestination }
    }

    // MARK: - Expand / Collapse

    func setSidebarExpanded(_ expanded: Bool) {
        isExpanded = expanded
        collapseButton.alpha = expanded ? 1 : 0

        for button in menuButtons {
            button.setExpanded(expanded)
        }
    }

    // MARK: - Focus

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        if let selected = selectedButton {
            return [selected]
        }
        return menuButtons.isEmpty ? [] : [menuButtons[0]]
    }
}
