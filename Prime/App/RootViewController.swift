import UIKit

final class RootViewController: UIViewController {

    let sidebarVC = SidebarViewController()
    private let contentContainerView = UIView()
    private let separatorView = UIView()

    private var sidebarWidthConstraint: NSLayoutConstraint!
    private let expandedWidth: CGFloat = 400
    private let collapsedWidth: CGFloat = 88

    private(set) var isSidebarExpanded = true
    private var focusIsInSidebar = true
    private var suppressSidebarExpand = false

    private var currentContentVC: UIViewController?
    private var currentDestination: SidebarDestination?
    private var cachedVCs: [SidebarDestination: UIViewController] = [:]
    private var navigationStack: [(vc: UIViewController, destination: SidebarDestination?, focusedView: UIView?)] = []

    // Remember which content view had focus before entering sidebar
    private weak var lastFocusedContentView: UIView?

    // Focus guide that covers the sidebar area — intercepts left-swipes from content
    // and directs them to the selected button
    private let sidebarFocusGuide = UIFocusGuide()

    // Focus guide in the gap for right-swipes from sidebar to content
    private let contentFocusGuide = UIFocusGuide()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppTheme.background
        setupSidebar()
        setupSeparator()
        setupContentContainer()
        setupFocusGuides()
        sidebarVC.delegate = self
        navigateTo(.home)
    }

    // MARK: - Layout

    private func setupSidebar() {
        addChild(sidebarVC)
        view.addSubview(sidebarVC.view)
        sidebarVC.view.translatesAutoresizingMaskIntoConstraints = false
        sidebarVC.didMove(toParent: self)

        sidebarWidthConstraint = sidebarVC.view.widthAnchor.constraint(equalToConstant: expandedWidth)

        NSLayoutConstraint.activate([
            sidebarVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            sidebarVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sidebarVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sidebarWidthConstraint
        ])
    }

    private func setupSeparator() {
        separatorView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(separatorView)

        NSLayoutConstraint.activate([
            separatorView.topAnchor.constraint(equalTo: view.topAnchor),
            separatorView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            separatorView.leadingAnchor.constraint(equalTo: sidebarVC.view.trailingAnchor),
            separatorView.widthAnchor.constraint(equalToConstant: 0)
        ])
    }

    private func setupContentContainer() {
        view.addSubview(contentContainerView)
        contentContainerView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            contentContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            contentContainerView.leadingAnchor.constraint(equalTo: separatorView.trailingAnchor),
            contentContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupFocusGuides() {
        // This guide sits between sidebar and content, full height.
        // When focus is in sidebar → points right to content (or last focused content view).
        // When focus is in content → points left to the selected sidebar button.
        view.addLayoutGuide(contentFocusGuide)
        NSLayoutConstraint.activate([
            contentFocusGuide.topAnchor.constraint(equalTo: view.topAnchor),
            contentFocusGuide.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentFocusGuide.leadingAnchor.constraint(equalTo: sidebarVC.view.trailingAnchor),
            contentFocusGuide.widthAnchor.constraint(equalToConstant: 20)
        ])
        contentFocusGuide.preferredFocusEnvironments = [contentContainerView]

        // This guide overlaps the collapsed sidebar area. When the sidebar is collapsed
        // and focus comes from the right (content), this catches it before the focus engine
        // can pick a button by Y-position, and routes to the selected button.
        view.addLayoutGuide(sidebarFocusGuide)
        NSLayoutConstraint.activate([
            sidebarFocusGuide.topAnchor.constraint(equalTo: view.topAnchor),
            sidebarFocusGuide.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sidebarFocusGuide.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sidebarFocusGuide.widthAnchor.constraint(equalTo: sidebarVC.view.widthAnchor)
        ])
        sidebarFocusGuide.isEnabled = false
    }

    // MARK: - Sidebar Expand/Collapse

    private func animateSidebar(expanded: Bool) {
        guard expanded != isSidebarExpanded else { return }
        isSidebarExpanded = expanded
        let targetWidth = expanded ? expandedWidth : collapsedWidth

        // Update constraints and button state before animating
        sidebarWidthConstraint.constant = targetWidth
        sidebarVC.setSidebarExpanded(expanded)

        UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseOut]) {
            self.view.layoutIfNeeded()
        }
    }

    // MARK: - Focus

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)

        guard let next = context.nextFocusedView else { return }
        let nextInSidebar = next.isDescendant(of: sidebarVC.view)
        let prevInContent = context.previouslyFocusedView.map { $0.isDescendant(of: contentContainerView) } ?? false

        // Save the last focused content view when leaving content
        if nextInSidebar && prevInContent, let prev = context.previouslyFocusedView {
            lastFocusedContentView = prev
        }

        // Hide/show search UI based on sidebar state
        if let searchVC = currentContentVC as? SearchViewController {
            if nextInSidebar {
                searchVC.dismissSearch()
            } else {
                searchVC.showSearch()
            }
        }

        focusIsInSidebar = nextInSidebar

        // Update focus guides based on where focus is now
        if nextInSidebar {
            // Focus is in sidebar — disable the sidebar overlay guide so user can navigate tabs
            sidebarFocusGuide.isEnabled = false

            // Content guide points back to last focused content view
            if let saved = lastFocusedContentView, saved.window != nil, saved.canBecomeFocused {
                contentFocusGuide.preferredFocusEnvironments = [saved]
            } else {
                contentFocusGuide.preferredFocusEnvironments = [contentContainerView]
            }
        } else {
            // Focus is in content — enable the sidebar overlay guide pointing to selected button
            // This intercepts left-swipes before the focus engine can pick by Y-position
            if let btn = sidebarVC.selectedButton {
                sidebarFocusGuide.preferredFocusEnvironments = [btn]
                contentFocusGuide.preferredFocusEnvironments = [btn]
            }
            sidebarFocusGuide.isEnabled = true
        }

        // Expand/collapse
        if suppressSidebarExpand {
            // During back navigation, don't expand sidebar even if focus passes through it
            if !nextInSidebar {
                suppressSidebarExpand = false
                if isSidebarExpanded {
                    coordinator.addCoordinatedAnimations({
                        self.animateSidebar(expanded: false)
                    }, completion: nil)
                }
            }
        } else if nextInSidebar && !isSidebarExpanded {
            coordinator.addCoordinatedAnimations({
                self.animateSidebar(expanded: true)
            }, completion: nil)
        } else if !nextInSidebar && isSidebarExpanded {
            coordinator.addCoordinatedAnimations({
                self.animateSidebar(expanded: false)
            }, completion: nil)
        }
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        if focusIsInSidebar {
            return [sidebarVC]
        } else if let saved = lastFocusedContentView, saved.window != nil {
            return [saved]
        } else if let content = currentContentVC {
            return [content]
        }
        return [sidebarVC]
    }

    // MARK: - Navigation

    func navigateTo(_ destination: SidebarDestination) {
        // Don't reload if we're already on this tab
        guard destination != currentDestination else { return }
        currentDestination = destination

        // Use cached VC if available, otherwise create new
        let newVC: UIViewController
        if let cached = cachedVCs[destination] {
            newVC = cached
        } else {
            switch destination {
            case .home:
                newVC = HomeViewController()
            case .movies:
                newVC = LibraryViewController(libraryType: .movies)
            case .tvShows:
                newVC = LibraryViewController(libraryType: .tvShows)
            case .liveTV:
                newVC = LiveTVViewController()
            case .search:
                newVC = SearchViewController()
            case .settings:
                newVC = SettingsViewController()
            }
            cachedVCs[destination] = newVC
        }

        lastFocusedContentView = nil
        transitionToContent(newVC)
    }

    /// Push a detail view into the content area (keeps sidebar visible)
    func showDetail(_ detailVC: UIViewController) {
        // Save current state to stack before navigating, including the currently focused view
        if let currentVC = currentContentVC {
            let focused = UIScreen.main.focusedView
            navigationStack.append((vc: currentVC, destination: currentDestination, focusedView: focused))
        }
        currentDestination = nil
        lastFocusedContentView = nil
        transitionToContent(detailVC)
    }

    /// Go back to the previous page in the navigation stack
    func goBack() {
        guard let previous = navigationStack.popLast() else { return }
        suppressSidebarExpand = true
        focusIsInSidebar = false
        currentDestination = previous.destination
        lastFocusedContentView = previous.focusedView
        transitionToContent(previous.vc)
        setNeedsFocusUpdate()
        updateFocusIfNeeded()
    }

    /// Navigate back to a tab (used by detail pages on Menu press)
    func navigateBack(to destination: SidebarDestination) {
        navigationStack.removeAll()
        suppressSidebarExpand = true
        focusIsInSidebar = false
        currentDestination = nil // force reload
        navigateTo(destination)
        setNeedsFocusUpdate()
        updateFocusIfNeeded()
    }

    private func transitionToContent(_ newVC: UIViewController) {
        let oldVC = currentContentVC

        if newVC.parent !== self {
            addChild(newVC)
        }
        if newVC.view.superview !== contentContainerView {
            newVC.view.alpha = 0
            contentContainerView.addSubview(newVC.view)
            newVC.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                newVC.view.topAnchor.constraint(equalTo: contentContainerView.topAnchor),
                newVC.view.leadingAnchor.constraint(equalTo: contentContainerView.leadingAnchor),
                newVC.view.trailingAnchor.constraint(equalTo: contentContainerView.trailingAnchor),
                newVC.view.bottomAnchor.constraint(equalTo: contentContainerView.bottomAnchor)
            ])

            UIView.animate(withDuration: 0.15) {
                newVC.view.alpha = 1
            }
        }
        newVC.didMove(toParent: self)
        currentContentVC = newVC

        if let oldVC, oldVC !== newVC {
            let isInStack = navigationStack.contains { $0.vc === oldVC }
            if isInStack {
                // Keep in parent but hide — we may navigate back to it
                oldVC.view.removeFromSuperview()
            } else {
                oldVC.willMove(toParent: nil)
                oldVC.view.removeFromSuperview()
                oldVC.removeFromParent()
            }
        }
    }

    // MARK: - Back Button

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            if press.type == .menu {
                if !navigationStack.isEmpty {
                    goBack()
                    return
                }
                // On a root tab — don't exit the app, do nothing
                // (tvOS will only exit if we call super)
                return
            }
        }
        super.pressesBegan(presses, with: event)
    }
}

// MARK: - SidebarDelegate

extension RootViewController: SidebarDelegate {
    func sidebarDidSelectDestination(_ destination: SidebarDestination) {
        navigateTo(destination)
        if destination == .search {
            animateSidebar(expanded: false)
            focusIsInSidebar = false
        }
    }

    func sidebarDidRequestToggle() {
        animateSidebar(expanded: !isSidebarExpanded)
    }
}
