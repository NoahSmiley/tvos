import UIKit

final class LiveTVViewController: UIViewController {

    private let categoryCollectionView: UICollectionView
    private let channelTableView = UITableView(frame: .zero, style: .plain)

    private var categories: [XtreamCategory] = []
    private var streams: [XtreamStream] = []
    private var selectedCategoryIndex = 0

    override init(nibName: String?, bundle: Bundle?) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 200, height: 50)
        layout.minimumInteritemSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 24)
        categoryCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nibName, bundle: bundle)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupHeader()
        setupCategoryBar()
        setupChannelTable()
        loadCategories()
    }

    // MARK: - Setup

    private func setupHeader() {
        let label = UILabel()
        label.text = "Live TV"
        label.font = .systemFont(ofSize: 48, weight: .bold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        label.tag = 500
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.topAnchor, constant: 60),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 48)
        ])
    }

    private func setupCategoryBar() {
        categoryCollectionView.backgroundColor = .clear
        categoryCollectionView.showsHorizontalScrollIndicator = false
        categoryCollectionView.register(CategoryPillCell.self, forCellWithReuseIdentifier: "CategoryPill")
        categoryCollectionView.dataSource = self
        categoryCollectionView.delegate = self
        categoryCollectionView.translatesAutoresizingMaskIntoConstraints = false
        categoryCollectionView.tag = 501
        view.addSubview(categoryCollectionView)

        let header = view.viewWithTag(500)!
        NSLayoutConstraint.activate([
            categoryCollectionView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 24),
            categoryCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 48),
            categoryCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            categoryCollectionView.heightAnchor.constraint(equalToConstant: 70)
        ])
    }

    private func setupChannelTable() {
        channelTableView.backgroundColor = .clear
        channelTableView.register(XtreamChannelCell.self, forCellReuseIdentifier: "XtreamChannel")
        channelTableView.dataSource = self
        channelTableView.delegate = self
        channelTableView.rowHeight = 80
        channelTableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(channelTableView)

        let catBar = view.viewWithTag(501)!
        NSLayoutConstraint.activate([
            channelTableView.topAnchor.constraint(equalTo: catBar.bottomAnchor, constant: 16),
            channelTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            channelTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            channelTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - Data Loading

    private func loadCategories() {
        Task {
            do {
                categories = try await XtreamAPI.shared.getCategories()
                categoryCollectionView.reloadData()

                if let first = categories.first {
                    loadStreams(categoryId: first.categoryId)
                }
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    private func loadStreams(categoryId: String) {
        Task {
            do {
                streams = try await XtreamAPI.shared.getLiveStreams(categoryId: categoryId)
                channelTableView.reloadData()
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    private func showError(_ message: String) {
        let label = UILabel()
        label.text = message
        label.font = .systemFont(ofSize: 28, weight: .medium)
        label.textColor = UIColor(red: 1, green: 0.4, blue: 0.4, alpha: 1)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -100)
        ])
    }
}

// MARK: - Category Collection

extension LiveTVViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        categories.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CategoryPill", for: indexPath) as! CategoryPillCell
        let cat = categories[indexPath.item]
        cell.configure(title: cat.categoryName, isSelected: indexPath.item == selectedCategoryIndex)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedCategoryIndex = indexPath.item
        categoryCollectionView.reloadData()
        loadStreams(categoryId: categories[indexPath.item].categoryId)
    }
}

// MARK: - Channel Table

extension LiveTVViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        streams.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "XtreamChannel", for: indexPath) as! XtreamChannelCell
        cell.configure(with: streams[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let stream = streams[indexPath.row]
        guard let url = XtreamAPI.shared.streamURL(for: stream.streamId) else { return }

        let playerVC = PlayerViewController(
            streamURL: url,
            itemId: nil,
            title: stream.name,
            startPositionTicks: 0
        )
        present(playerVC, animated: true)
    }
}

// MARK: - Category Pill Cell

final class CategoryPillCell: UICollectionViewCell {

    private let label = UILabel()
    private let accentColor = UIColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0)

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 25
        contentView.clipsToBounds = true

        label.font = .systemFont(ofSize: 22, weight: .semibold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -16)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, isSelected: Bool) {
        label.text = title
        label.textColor = isSelected ? .white : .gray
        contentView.backgroundColor = isSelected ? accentColor : UIColor(white: 0.15, alpha: 1)
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                self.contentView.backgroundColor = self.accentColor.withAlphaComponent(0.8)
                self.label.textColor = .white
            } else {
                self.transform = .identity
            }
        }, completion: nil)
    }
}

// MARK: - Xtream Channel Cell

final class XtreamChannelCell: UITableViewCell {

    private let logoImageView = UIImageView()
    private let channelNameLabel = UILabel()
    private let liveIndicator = UIView()

    private var loadTask: Task<Void, Never>?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        backgroundColor = .clear
        selectionStyle = .none

        logoImageView.contentMode = .scaleAspectFit
        logoImageView.clipsToBounds = true
        logoImageView.layer.cornerRadius = 8
        logoImageView.backgroundColor = UIColor(white: 0.15, alpha: 1)
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(logoImageView)

        channelNameLabel.font = .systemFont(ofSize: 26, weight: .semibold)
        channelNameLabel.textColor = .white
        channelNameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(channelNameLabel)

        liveIndicator.backgroundColor = UIColor(red: 1, green: 0.3, blue: 0.3, alpha: 1)
        liveIndicator.layer.cornerRadius = 5
        liveIndicator.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(liveIndicator)

        NSLayoutConstraint.activate([
            logoImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            logoImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 60),
            logoImageView.heightAnchor.constraint(equalToConstant: 60),

            channelNameLabel.leadingAnchor.constraint(equalTo: logoImageView.trailingAnchor, constant: 16),
            channelNameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            channelNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: liveIndicator.leadingAnchor, constant: -16),

            liveIndicator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            liveIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            liveIndicator.widthAnchor.constraint(equalToConstant: 10),
            liveIndicator.heightAnchor.constraint(equalToConstant: 10)
        ])
    }

    func configure(with stream: XtreamStream) {
        channelNameLabel.text = stream.name

        loadTask?.cancel()
        logoImageView.image = nil
        if let iconStr = stream.streamIcon, let iconURL = URL(string: iconStr) {
            loadTask = Task {
                let image = await ImageLoader.shared.loadImage(from: iconURL)
                if !Task.isCancelled { logoImageView.image = image }
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        loadTask?.cancel()
        logoImageView.image = nil
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations({
            self.contentView.backgroundColor = self.isFocused ? UIColor.white.withAlphaComponent(0.1) : .clear
            self.contentView.layer.cornerRadius = 12
        }, completion: nil)
    }
}
