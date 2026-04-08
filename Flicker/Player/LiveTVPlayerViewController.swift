import UIKit
import AVKit

/// Live TV player with channel surf overlay.
/// Swipe up/down to browse channels, select to switch.
final class LiveTVPlayerViewController: AVPlayerViewController {

    private var currentStream: XtreamStream
    private let channels: [XtreamStream] // all channels in current category
    private let cleanName: (XtreamStream) -> String

    private var reportTimer: Timer?
    private var statusObserver: NSKeyValueObservation?

    // Channel surf overlay
    private let surfOverlay = UIView()
    private let surfStack = UIStackView()
    private let surfScroll = UIScrollView()
    private let channelInfoLabel = UILabel()
    private let nowPlayingInfoLabel = UILabel()
    private var surfTimer: Timer?
    private var isSurfVisible = false
    private var currentChannelIndex: Int

    var onChannelChanged: ((XtreamStream) -> Void)?

    init(stream: XtreamStream, channels: [XtreamStream], cleanName: @escaping (XtreamStream) -> String) {
        self.currentStream = stream
        self.channels = channels
        self.cleanName = cleanName
        self.currentChannelIndex = channels.firstIndex(where: { $0.streamId == stream.streamId }) ?? 0
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSurfOverlay()
        loadStream(currentStream)
        setupGestures()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        reportTimer?.invalidate()
        statusObserver?.invalidate()
        player?.pause()
    }

    // MARK: - Stream Loading

    private func loadStream(_ stream: XtreamStream) {
        currentStream = stream
        player?.pause()
        reportTimer?.invalidate()
        statusObserver?.invalidate()

        guard let url = XtreamAPI.shared.streamURL(for: stream.streamId) else { return }

        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)

        statusObserver = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            if item.status == .readyToPlay {
                self?.player?.play()
            }
        }

        // Set title metadata
        let titleItem = AVMutableMetadataItem()
        titleItem.identifier = .commonIdentifierTitle
        titleItem.value = cleanName(stream) as NSString
        playerItem.externalMetadata = [titleItem]

        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }

        // Update channel info on overlay
        channelInfoLabel.text = cleanName(stream)
        nowPlayingInfoLabel.text = "Loading..."

        Task {
            let program = await XtreamAPI.shared.getCurrentProgram(streamId: stream.streamId)
            if let program {
                var text = program.decodedTitle
                if let mins = program.minutesRemaining {
                    text += " · \(mins)m left"
                }
                nowPlayingInfoLabel.text = text
            } else {
                nowPlayingInfoLabel.text = "Live"
            }
        }
    }

    // MARK: - Surf Overlay

    private func setupSurfOverlay() {
        surfOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        surfOverlay.alpha = 0
        surfOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(surfOverlay)

        // Current channel info at top of overlay
        let infoStack = UIStackView()
        infoStack.axis = .vertical
        infoStack.spacing = 4
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        surfOverlay.addSubview(infoStack)

        channelInfoLabel.font = .systemFont(ofSize: 32, weight: .bold)
        channelInfoLabel.textColor = .white
        channelInfoLabel.text = cleanName(currentStream)
        infoStack.addArrangedSubview(channelInfoLabel)

        nowPlayingInfoLabel.font = .systemFont(ofSize: 22, weight: .regular)
        nowPlayingInfoLabel.textColor = UIColor(white: 0.6, alpha: 1)
        nowPlayingInfoLabel.text = "Live"
        infoStack.addArrangedSubview(nowPlayingInfoLabel)

        // Channel strip scroll
        surfScroll.showsHorizontalScrollIndicator = false
        surfScroll.clipsToBounds = false
        surfScroll.translatesAutoresizingMaskIntoConstraints = false
        surfOverlay.addSubview(surfScroll)

        surfStack.axis = .horizontal
        surfStack.spacing = 12
        surfStack.translatesAutoresizingMaskIntoConstraints = false
        surfScroll.addSubview(surfStack)

        NSLayoutConstraint.activate([
            surfOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            surfOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            surfOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            surfOverlay.heightAnchor.constraint(equalToConstant: 220),

            infoStack.topAnchor.constraint(equalTo: surfOverlay.topAnchor, constant: 20),
            infoStack.leadingAnchor.constraint(equalTo: surfOverlay.leadingAnchor, constant: 60),

            surfScroll.topAnchor.constraint(equalTo: infoStack.bottomAnchor, constant: 16),
            surfScroll.leadingAnchor.constraint(equalTo: surfOverlay.leadingAnchor, constant: 60),
            surfScroll.trailingAnchor.constraint(equalTo: surfOverlay.trailingAnchor, constant: -60),
            surfScroll.bottomAnchor.constraint(equalTo: surfOverlay.bottomAnchor, constant: -20),

            surfStack.topAnchor.constraint(equalTo: surfScroll.topAnchor),
            surfStack.leadingAnchor.constraint(equalTo: surfScroll.leadingAnchor),
            surfStack.trailingAnchor.constraint(equalTo: surfScroll.trailingAnchor),
            surfStack.bottomAnchor.constraint(equalTo: surfScroll.bottomAnchor),
            surfStack.heightAnchor.constraint(equalTo: surfScroll.heightAnchor)
        ])

        buildSurfStrip()
    }

    private func buildSurfStrip() {
        surfStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // Show channels around current index
        let range = max(0, currentChannelIndex - 5)...min(channels.count - 1, currentChannelIndex + 15)

        for i in range {
            let ch = channels[i]
            let card = SurfChannelCard(stream: ch, name: cleanName(ch), isCurrent: i == currentChannelIndex)
            card.onSelect = { [weak self] in
                self?.switchToChannel(at: i)
            }
            surfStack.addArrangedSubview(card)
        }
    }

    private func switchToChannel(at index: Int) {
        guard index >= 0, index < channels.count else { return }
        currentChannelIndex = index
        let stream = channels[index]
        loadStream(stream)
        buildSurfStrip()
        onChannelChanged?(stream)
        scheduleSurfHide()
    }

    // MARK: - Gestures

    private func setupGestures() {
        let swipeUp = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeUp))
        swipeUp.direction = .up
        view.addGestureRecognizer(swipeUp)

        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeDown))
        swipeDown.direction = .down
        view.addGestureRecognizer(swipeDown)
    }

    @objc private func handleSwipeUp() {
        if !isSurfVisible {
            showSurf()
        } else {
            // Channel up
            let newIndex = currentChannelIndex - 1
            if newIndex >= 0 {
                switchToChannel(at: newIndex)
            }
        }
    }

    @objc private func handleSwipeDown() {
        if isSurfVisible {
            hideSurf()
        }
    }

    private func showSurf() {
        isSurfVisible = true
        buildSurfStrip()
        UIView.animate(withDuration: 0.3) {
            self.surfOverlay.alpha = 1
        }
        scheduleSurfHide()
    }

    private func hideSurf() {
        isSurfVisible = false
        surfTimer?.invalidate()
        UIView.animate(withDuration: 0.3) {
            self.surfOverlay.alpha = 0
        }
    }

    private func scheduleSurfHide() {
        surfTimer?.invalidate()
        surfTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: false) { [weak self] _ in
            self?.hideSurf()
        }
    }
}

// MARK: - Surf Channel Card

final class SurfChannelCard: UIButton {

    var onSelect: (() -> Void)?

    init(stream: XtreamStream, name: String, isCurrent: Bool) {
        super.init(frame: .zero)

        backgroundColor = isCurrent ? UIColor.white.withAlphaComponent(0.2) : UIColor(white: 0.15, alpha: 1)
        layer.cornerRadius = 10
        clipsToBounds = true

        if isCurrent {
            layer.borderWidth = 2
            layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        }

        let logo = UIImageView()
        logo.contentMode = .scaleAspectFit
        logo.tintColor = UIColor(white: 0.4, alpha: 1)
        logo.image = UIImage(systemName: "tv")
        logo.translatesAutoresizingMaskIntoConstraints = false
        addSubview(logo)

        let label = UILabel()
        label.text = name
        label.font = .systemFont(ofSize: 18, weight: isCurrent ? .bold : .medium)
        label.textColor = isCurrent ? .white : UIColor(white: 0.7, alpha: 1)
        label.numberOfLines = 2
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 150),
            heightAnchor.constraint(equalToConstant: 90),

            logo.centerXAnchor.constraint(equalTo: centerXAnchor),
            logo.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            logo.widthAnchor.constraint(equalToConstant: 32),
            logo.heightAnchor.constraint(equalToConstant: 32),

            label.topAnchor.constraint(equalTo: logo.bottomAnchor, constant: 4),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6)
        ])

        if let iconStr = stream.streamIcon, let iconURL = URL(string: iconStr) {
            Task {
                let image = await ImageLoader.shared.loadImage(from: iconURL)
                if let image {
                    logo.image = image
                    logo.tintColor = nil
                }
            }
        }

        addTarget(self, action: #selector(tapped), for: .primaryActionTriggered)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func tapped() { onSelect?() }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations({
            if self.isFocused {
                self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                self.backgroundColor = UIColor.white.withAlphaComponent(0.25)
            } else {
                self.transform = .identity
                self.backgroundColor = self.layer.borderWidth > 0
                    ? UIColor.white.withAlphaComponent(0.2)
                    : UIColor(white: 0.15, alpha: 1)
            }
        }, completion: nil)
    }
}
