import UIKit

final class EpisodesViewController: UIViewController {

    private let seriesId: String
    private let seasonId: String
    private let seasonName: String

    private let tableView = UITableView(frame: .zero, style: .plain)
    private var episodes: [JellyfinItem] = []

    init(seriesId: String, seasonId: String, seasonName: String) {
        self.seriesId = seriesId
        self.seasonId = seasonId
        self.seasonName = seasonName
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.background
        setupHeader()
        setupTableView()
        loadEpisodes()
    }

    private func setupHeader() {
        let backButton = UIButton(type: .system)
        backButton.setImage(UIImage(systemName: "arrow.left"), for: .normal)
        backButton.setTitle("  Back", for: .normal)
        backButton.titleLabel?.font = AppTheme.font(26, weight: .semibold)
        backButton.tintColor = .white
        backButton.addTarget(self, action: #selector(backTapped), for: .primaryActionTriggered)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backButton)

        let titleLabel = UILabel()
        titleLabel.text = seasonName
        titleLabel.font = AppTheme.font(44, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        titleLabel.tag = 400

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 40),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 60),
            titleLabel.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 60)
        ])
    }

    private func setupTableView() {
        tableView.backgroundColor = .clear
        tableView.register(EpisodeCell.self, forCellReuseIdentifier: "EpisodeCell")
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 140
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        let header = view.viewWithTag(400)!
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 32),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func loadEpisodes() {
        Task {
            do {
                episodes = try await JellyfinAPI.shared.getEpisodes(seriesId: seriesId, seasonId: seasonId)
                tableView.reloadData()
            } catch { }
        }
    }

    @objc private func backTapped() {
        dismiss(animated: true)
    }
}

extension EpisodesViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        episodes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "EpisodeCell", for: indexPath) as! EpisodeCell
        cell.configure(with: episodes[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let ep = episodes[indexPath.row]
        guard let url = JellyfinAPI.shared.playbackURL(itemId: ep.id) else { return }
        let startTicks = ep.userData?.playbackPositionTicks ?? 0
        let displayTitle = "S\(ep.parentIndexNumber ?? 0)E\(ep.indexNumber ?? 0) - \(ep.name)"
        let playerVC = PlayerViewController(streamURL: url, itemId: ep.id, title: displayTitle, startPositionTicks: startTicks)
        present(playerVC, animated: true)
    }
}

// MARK: - Episode Cell

