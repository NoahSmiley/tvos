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
        view.backgroundColor = UIColor(white: 0.04, alpha: 1)
        setupHeader()
        setupTableView()
        loadEpisodes()
    }

    private func setupHeader() {
        let backButton = UIButton(type: .system)
        backButton.setImage(UIImage(systemName: "arrow.left"), for: .normal)
        backButton.setTitle("  Back", for: .normal)
        backButton.titleLabel?.font = .systemFont(ofSize: 26, weight: .semibold)
        backButton.tintColor = .white
        backButton.addTarget(self, action: #selector(backTapped), for: .primaryActionTriggered)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backButton)

        let titleLabel = UILabel()
        titleLabel.text = seasonName
        titleLabel.font = .systemFont(ofSize: 44, weight: .bold)
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
        guard let url = JellyfinAPI.shared.getStreamURL(itemId: ep.id)
                ?? JellyfinAPI.shared.getTranscodeURL(itemId: ep.id) else { return }
        let startTicks = ep.userData?.playbackPositionTicks ?? 0
        let displayTitle = "S\(ep.parentIndexNumber ?? 0)E\(ep.indexNumber ?? 0) - \(ep.name)"
        let playerVC = PlayerViewController(streamURL: url, itemId: ep.id, title: displayTitle, startPositionTicks: startTicks)
        present(playerVC, animated: true)
    }
}

// MARK: - Episode Cell

final class EpisodeCell: UITableViewCell {

    private let thumbImageView = UIImageView()
    private let epTitleLabel = UILabel()
    private let epNumberLabel = UILabel()
    private let epOverviewLabel = UILabel()

    private var loadTask: Task<Void, Never>?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        backgroundColor = .clear
        selectionStyle = .none

        thumbImageView.contentMode = .scaleAspectFill
        thumbImageView.clipsToBounds = true
        thumbImageView.layer.cornerRadius = 10
        thumbImageView.backgroundColor = UIColor(white: 0.15, alpha: 1)
        thumbImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(thumbImageView)

        epNumberLabel.font = .systemFont(ofSize: 20, weight: .bold)
        epNumberLabel.textColor = UIColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0)
        epNumberLabel.translatesAutoresizingMaskIntoConstraints = false

        epTitleLabel.font = .systemFont(ofSize: 26, weight: .semibold)
        epTitleLabel.textColor = .white
        epTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        epOverviewLabel.font = .systemFont(ofSize: 20, weight: .regular)
        epOverviewLabel.textColor = .gray
        epOverviewLabel.numberOfLines = 2
        epOverviewLabel.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [epNumberLabel, epTitleLabel, epOverviewLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textStack)

        NSLayoutConstraint.activate([
            thumbImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            thumbImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            thumbImageView.widthAnchor.constraint(equalToConstant: 180),
            thumbImageView.heightAnchor.constraint(equalToConstant: 100),

            textStack.leadingAnchor.constraint(equalTo: thumbImageView.trailingAnchor, constant: 20),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            textStack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    func configure(with episode: JellyfinItem) {
        epNumberLabel.text = "Episode \(episode.indexNumber ?? 0)"
        epTitleLabel.text = episode.name
        epOverviewLabel.text = episode.overview

        loadTask?.cancel()
        thumbImageView.image = nil
        loadTask = Task {
            let image = await ImageLoader.shared.loadImage(from: episode.primaryImageURL)
            if !Task.isCancelled { thumbImageView.image = image }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        loadTask?.cancel()
        thumbImageView.image = nil
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations({
            self.contentView.backgroundColor = self.isFocused ? UIColor.white.withAlphaComponent(0.1) : .clear
            self.contentView.layer.cornerRadius = 12
        }, completion: nil)
    }
}
