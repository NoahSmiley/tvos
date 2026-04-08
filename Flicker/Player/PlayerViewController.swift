import UIKit
import AVKit

final class PlayerViewController: AVPlayerViewController {

    private var streamURL: URL
    private let itemId: String?
    private let mediaTitle: String
    private let startPositionTicks: Int64
    private var hasTriedFallback = false

    private var reportTimer: Timer?
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

    override func viewDidLoad() {
        super.viewDidLoad()
        setupPlayer()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopPlayback()
    }

    // MARK: - Setup

    private func setupPlayer() {
        print("[Player] Loading: \(streamURL.absoluteString)")

        let asset = AVURLAsset(url: streamURL)
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 5 // Start playing sooner

        // Observe status for errors
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
        avPlayer.automaticallyWaitsToMinimizeStalling = false // Play ASAP
        player = avPlayer

        // Set metadata for the native tvOS player UI
        let titleItem = AVMutableMetadataItem()
        titleItem.identifier = .commonIdentifierTitle
        titleItem.value = mediaTitle as NSString
        playerItem.externalMetadata = [titleItem]
    }

    // MARK: - Playback

    private func beginPlayback() {
        // Seek to saved position
        if startPositionTicks > 0 {
            let seconds = Double(startPositionTicks) / 10_000_000.0
            player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 1000)) { [weak self] _ in
                self?.player?.play()
            }
        } else {
            player?.play()
        }

        // Report playback start to Jellyfin
        if let itemId {
            Task { await JellyfinAPI.shared.reportPlaybackStart(itemId: itemId, positionTicks: startPositionTicks) }
        }

        // Report progress every 10 seconds
        reportTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.reportProgress()
        }
    }

    private func stopPlayback() {
        reportTimer?.invalidate()
        reportTimer = nil
        statusObserver?.invalidate()
        player?.pause()

        // Report stop to Jellyfin
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

    // MARK: - Fallback & Error

    private func tryFallbackOrShowError(_ message: String) {
        guard !hasTriedFallback, let itemId else {
            showError(message)
            return
        }

        hasTriedFallback = true
        print("[Player] Trying HLS transcode fallback...")

        // Try HLS transcode as fallback
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
