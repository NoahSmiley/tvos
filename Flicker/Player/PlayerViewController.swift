import UIKit
import AVKit

final class PlayerViewController: AVPlayerViewController {

    private let streamURL: URL
    private let itemId: String?
    private let mediaTitle: String
    private let startPositionTicks: Int64

    private var reportTimer: Timer?
    private var statusObserver: NSKeyValueObservation?
    private var errorObserver: NSKeyValueObservation?

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

        // Observe status for errors
        statusObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            switch item.status {
            case .readyToPlay:
                print("[Player] Ready to play")
                self?.beginPlayback()
            case .failed:
                print("[Player] Failed: \(item.error?.localizedDescription ?? "unknown")")
                self?.showError(item.error?.localizedDescription ?? "Failed to load media")
            default:
                break
            }
        }

        errorObserver = playerItem.observe(\.error, options: [.new]) { _, change in
            if let error = change.newValue as? Error {
                print("[Player] Error: \(error.localizedDescription)")
            }
        }

        let avPlayer = AVPlayer(playerItem: playerItem)
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
        errorObserver?.invalidate()
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

    // MARK: - Error

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Playback Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
}
