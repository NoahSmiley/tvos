import UIKit
import AVKit

final class PlayerViewController: UIViewController {

    private let streamURL: URL
    private let itemId: String?
    private let mediaTitle: String
    private let startPositionTicks: Int64

    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    private var timeObserver: Any?

    private let overlayView = UIView()
    private let titleLabel = UILabel()
    private let timeLabel = UILabel()
    private let progressBar = UIProgressView(progressViewStyle: .default)
    private var overlayTimer: Timer?
    private var isOverlayVisible = true

    private var reportTimer: Timer?

    init(streamURL: URL, itemId: String?, title: String, startPositionTicks: Int64) {
        self.streamURL = streamURL
        self.itemId = itemId
        self.mediaTitle = title
        self.startPositionTicks = startPositionTicks
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupPlayer()
        setupOverlay()
        setupGestures()
        startPlayback()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopPlayback()
    }

    // MARK: - Setup

    private func setupPlayer() {
        let asset = AVURLAsset(url: streamURL)
        let playerItem = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: playerItem)

        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.videoGravity = .resizeAspect
        playerLayer?.frame = view.bounds
        view.layer.addSublayer(playerLayer!)
    }

    private func setupOverlay() {
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlayView)
        NSLayoutConstraint.activate([
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            overlayView.heightAnchor.constraint(equalToConstant: 120)
        ])

        titleLabel.text = mediaTitle
        titleLabel.font = .systemFont(ofSize: 30, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        overlayView.addSubview(titleLabel)

        timeLabel.font = .systemFont(ofSize: 24, weight: .medium)
        timeLabel.textColor = .gray
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        overlayView.addSubview(timeLabel)

        progressBar.progressTintColor = UIColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0)
        progressBar.trackTintColor = UIColor(white: 0.3, alpha: 1)
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        overlayView.addSubview(progressBar)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: overlayView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 60),

            timeLabel.topAnchor.constraint(equalTo: overlayView.topAnchor, constant: 20),
            timeLabel.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor, constant: -60),

            progressBar.bottomAnchor.constraint(equalTo: overlayView.bottomAnchor, constant: -30),
            progressBar.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 60),
            progressBar.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor, constant: -60),
            progressBar.heightAnchor.constraint(equalToConstant: 6)
        ])
    }

    private func setupGestures() {
        let menuPress = UITapGestureRecognizer(target: self, action: #selector(menuPressed))
        menuPress.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
        view.addGestureRecognizer(menuPress)

        let playPausePress = UITapGestureRecognizer(target: self, action: #selector(playPausePressed))
        playPausePress.allowedPressTypes = [NSNumber(value: UIPress.PressType.playPause.rawValue)]
        view.addGestureRecognizer(playPausePress)

        let selectPress = UITapGestureRecognizer(target: self, action: #selector(selectPressed))
        selectPress.allowedPressTypes = [NSNumber(value: UIPress.PressType.select.rawValue)]
        view.addGestureRecognizer(selectPress)
    }

    // MARK: - Playback

    private func startPlayback() {
        // Seek to saved position
        if startPositionTicks > 0 {
            let seconds = Double(startPositionTicks) / 10_000_000.0
            player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 1000))
        }

        player?.play()

        // Report playback start
        if let itemId {
            Task { await JellyfinAPI.shared.reportPlaybackStart(itemId: itemId, positionTicks: startPositionTicks) }
        }

        // Time observer
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 1),
            queue: .main
        ) { [weak self] time in
            self?.updateTimeDisplay(time)
        }

        // Report progress every 10 seconds
        reportTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.reportProgress()
        }

        // Auto-hide overlay
        scheduleOverlayHide()
    }

    private func stopPlayback() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        reportTimer?.invalidate()
        player?.pause()

        // Report stop
        if let itemId {
            let ticks = currentPositionTicks()
            Task { await JellyfinAPI.shared.reportPlaybackStopped(itemId: itemId, positionTicks: ticks) }
        }
    }

    private func updateTimeDisplay(_ time: CMTime) {
        let current = time.seconds
        let duration = player?.currentItem?.duration.seconds ?? 0

        guard current.isFinite && duration.isFinite && duration > 0 else { return }

        timeLabel.text = "\(formatTime(current)) / \(formatTime(duration))"
        progressBar.progress = Float(current / duration)
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

    // MARK: - Overlay

    private func toggleOverlay() {
        isOverlayVisible.toggle()
        UIView.animate(withDuration: 0.3) {
            self.overlayView.alpha = self.isOverlayVisible ? 1 : 0
        }
        if isOverlayVisible {
            scheduleOverlayHide()
        }
    }

    private func scheduleOverlayHide() {
        overlayTimer?.invalidate()
        overlayTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            guard let self, self.isOverlayVisible else { return }
            UIView.animate(withDuration: 0.3) { self.overlayView.alpha = 0 }
            self.isOverlayVisible = false
        }
    }

    // MARK: - Actions

    @objc private func menuPressed() {
        dismiss(animated: true)
    }

    @objc private func playPausePressed() {
        if player?.rate == 0 {
            player?.play()
        } else {
            player?.pause()
        }
    }

    @objc private func selectPressed() {
        toggleOverlay()
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: Double) -> String {
        let hrs = Int(seconds) / 3600
        let mins = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hrs > 0 {
            return String(format: "%d:%02d:%02d", hrs, mins, secs)
        }
        return String(format: "%d:%02d", mins, secs)
    }
}
