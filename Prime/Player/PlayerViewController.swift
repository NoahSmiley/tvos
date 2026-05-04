import UIKit
import AVKit

final class PlayerViewController: AVPlayerViewController {

    private var streamURL: URL
    private let itemId: String?
    private let mediaTitle: String
    private let startPositionTicks: Int64
    private var hasTriedFallback = false

    // Chapter-based features
    private var chapters: [JellyfinChapter] = []
    private var introStartSeconds: Double?
    private var introEndSeconds: Double?
    private var creditsStartSeconds: Double?
    private var totalDurationSeconds: Double?

    // Next episode
    private var nextEpisode: JellyfinItem?
    var onPlayNextEpisode: ((JellyfinItem) -> Void)?

    // Overlay buttons
    private let skipIntroButton = UIButton(type: .custom)
    private let nextEpisodeButton = UIButton(type: .custom)
    private var skipIntroShown = false
    private var nextEpisodeShown = false

    private var reportTimer: Timer?
    private var positionTimer: Timer?
    private var statusObserver: NSKeyValueObservation?

    init(streamURL: URL, itemId: String?, title: String, startPositionTicks: Int64) {
        self.streamURL = streamURL
        self.itemId = itemId
        self.mediaTitle = title
        self.startPositionTicks = startPositionTicks
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Configure with chapter data from a JellyfinItem
    func configureChapters(from item: JellyfinItem) {
        guard let chs = item.chapters, !chs.isEmpty else { return }
        self.chapters = chs
        self.totalDurationSeconds = item.runTimeTicks.map { Double($0) / 10_000_000.0 }

        // Find intro chapter
        for (i, ch) in chs.enumerated() {
            let name = ch.name?.lowercased() ?? ""
            if name.contains("intro") {
                introStartSeconds = ch.startSeconds
                // Intro ends at the next chapter
                if i + 1 < chs.count {
                    introEndSeconds = chs[i + 1].startSeconds
                }
            }
            if name.contains("credit") {
                creditsStartSeconds = ch.startSeconds
            }
        }

        print("[Player] Chapters: intro=\(introStartSeconds ?? -1)-\(introEndSeconds ?? -1), credits=\(creditsStartSeconds ?? -1)")
    }

    /// Set the next episode for auto-play
    func setNextEpisode(_ episode: JellyfinItem?) {
        self.nextEpisode = episode
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupOverlayButtons()
        setupPlayer()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopPlayback()
    }

    // MARK: - Overlay Buttons

    private func setupOverlayButtons() {
        // Skip Intro button
        configureOverlayButton(skipIntroButton, title: "Skip Intro", icon: "forward.fill")
        skipIntroButton.addTarget(self, action: #selector(skipIntroTapped), for: .primaryActionTriggered)
        view.addSubview(skipIntroButton)

        // Next Episode button
        configureOverlayButton(nextEpisodeButton, title: "Next Episode", icon: "forward.end.fill")
        nextEpisodeButton.addTarget(self, action: #selector(nextEpisodeTapped), for: .primaryActionTriggered)
        view.addSubview(nextEpisodeButton)

        NSLayoutConstraint.activate([
            skipIntroButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -80),
            skipIntroButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -120),

            nextEpisodeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -80),
            nextEpisodeButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -120)
        ])
    }

    private func configureOverlayButton(_ button: UIButton, title: String, icon: String) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.alpha = 0
        button.isHidden = true

        var config = UIButton.Configuration.filled()
        config.title = title
        config.image = UIImage(systemName: icon)
        config.imagePadding = 10
        config.baseForegroundColor = .white
        config.baseBackgroundColor = UIColor(white: 0.15, alpha: 0.9)
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 28, bottom: 16, trailing: 28)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attr in
            var attr = attr
            attr.font = AppTheme.font(24, weight: .bold)
            return attr
        }
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        button.configuration = config
    }

    // MARK: - Setup

    private func setupPlayer() {
        print("[Player] Loading: \(streamURL.absoluteString)")

        let asset = AVURLAsset(url: streamURL)
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 5

        statusObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            switch item.status {
            case .readyToPlay:
                print("[Player] Ready to play")
                self?.beginPlayback()
            case .failed:
                print("[Player] Failed: \(item.error?.localizedDescription ?? "unknown")")
                self?.tryFallbackOrShowError(item.error?.localizedDescription ?? "Failed to load media")
            default:
                break
            }
        }

        let avPlayer = AVPlayer(playerItem: playerItem)
        avPlayer.automaticallyWaitsToMinimizeStalling = false
        player = avPlayer

        let titleItem = AVMutableMetadataItem()
        titleItem.identifier = .commonIdentifierTitle
        titleItem.value = mediaTitle as NSString
        playerItem.externalMetadata = [titleItem]
    }

    // MARK: - Playback

    private func beginPlayback() {
        if startPositionTicks > 0 {
            let seconds = Double(startPositionTicks) / 10_000_000.0
            player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 1000)) { [weak self] _ in
                self?.player?.play()
            }
        } else {
            player?.play()
        }

        if let itemId {
            Task { await JellyfinAPI.shared.reportPlaybackStart(itemId: itemId, positionTicks: startPositionTicks) }
        }

        reportTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.reportProgress()
        }

        // Monitor position for skip intro / next episode
        positionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.checkPosition()
        }
    }

    private func stopPlayback() {
        reportTimer?.invalidate()
        reportTimer = nil
        positionTimer?.invalidate()
        positionTimer = nil
        statusObserver?.invalidate()
        player?.pause()

        if let itemId {
            let ticks = currentPositionTicks()
            Task { await JellyfinAPI.shared.reportPlaybackStopped(itemId: itemId, positionTicks: ticks) }
        }
    }

    private func reportProgress() {
        guard let itemId else { return }
        let ticks = currentPositionTicks()
        let isPaused = player?.rate == 0
        Task { await JellyfinAPI.shared.reportPlaybackProgress(itemId: itemId, positionTicks: ticks, isPaused: isPaused) }
    }

    private func currentPositionTicks() -> Int64 {
        guard let time = player?.currentTime(), time.seconds.isFinite else { return 0 }
        return Int64(time.seconds * 10_000_000)
    }

    // MARK: - Position Monitoring

    private func checkPosition() {
        guard let time = player?.currentTime(), time.seconds.isFinite else { return }
        let pos = time.seconds

        // Skip Intro: show when we're in the intro chapter
        if let introStart = introStartSeconds, let introEnd = introEndSeconds {
            if pos >= introStart && pos < introEnd && !skipIntroShown {
                showButton(skipIntroButton)
                skipIntroShown = true
            } else if (pos < introStart || pos >= introEnd) && skipIntroShown {
                hideButton(skipIntroButton)
                skipIntroShown = false
            }
        }

        // Next Episode: show during credits or last 90 seconds
        if nextEpisode != nil {
            let inCredits: Bool
            if let creditsStart = creditsStartSeconds {
                inCredits = pos >= creditsStart
            } else if let total = totalDurationSeconds, total > 0 {
                inCredits = pos >= total - 90
            } else if let duration = player?.currentItem?.duration.seconds, duration.isFinite, duration > 0 {
                inCredits = pos >= duration - 90
            } else {
                inCredits = false
            }

            if inCredits && !nextEpisodeShown {
                showButton(nextEpisodeButton)
                nextEpisodeShown = true
            } else if !inCredits && nextEpisodeShown {
                hideButton(nextEpisodeButton)
                nextEpisodeShown = false
            }
        }
    }

    // MARK: - Button Actions

    @objc private func skipIntroTapped() {
        guard let introEnd = introEndSeconds else { return }
        player?.seek(to: CMTime(seconds: introEnd, preferredTimescale: 1000))
        hideButton(skipIntroButton)
        skipIntroShown = false
    }

    @objc private func nextEpisodeTapped() {
        guard let next = nextEpisode else { return }
        stopPlayback()
        dismiss(animated: true) { [weak self] in
            self?.onPlayNextEpisode?(next)
        }
    }

    // MARK: - Button Animation

    private func showButton(_ button: UIButton) {
        button.isHidden = false
        UIView.animate(withDuration: 0.4) {
            button.alpha = 1
        }
    }

    private func hideButton(_ button: UIButton) {
        UIView.animate(withDuration: 0.3) {
            button.alpha = 0
        } completion: { _ in
            button.isHidden = true
        }
    }

    // MARK: - Fallback & Error

    private func tryFallbackOrShowError(_ message: String) {
        guard !hasTriedFallback, let itemId else {
            showError(message)
            return
        }

        hasTriedFallback = true
        print("[Player] Trying HLS transcode fallback...")

        guard let fallbackURL = JellyfinAPI.shared.getTranscodeURL(itemId: itemId) else {
            showError(message)
            return
        }

        streamURL = fallbackURL
        statusObserver?.invalidate()
        player?.pause()

        let asset = AVURLAsset(url: fallbackURL)
        let newItem = AVPlayerItem(asset: asset)
        newItem.preferredForwardBufferDuration = 5

        statusObserver = newItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            switch item.status {
            case .readyToPlay:
                print("[Player] Fallback ready to play")
                self?.beginPlayback()
            case .failed:
                print("[Player] Fallback also failed")
                self?.showError(item.error?.localizedDescription ?? "Failed to load media")
            default:
                break
            }
        }

        let titleItem = AVMutableMetadataItem()
        titleItem.identifier = .commonIdentifierTitle
        titleItem.value = mediaTitle as NSString
        newItem.externalMetadata = [titleItem]

        player?.replaceCurrentItem(with: newItem)
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Playback Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
}
