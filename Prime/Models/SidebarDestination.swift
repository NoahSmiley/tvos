import UIKit

enum SidebarDestination: Int, CaseIterable {
    case home
    case movies
    case tvShows
    case liveTV
    case search
    case settings

    var title: String {
        switch self {
        case .home: return "Home"
        case .movies: return "Movies"
        case .tvShows: return "TV Shows"
        case .liveTV: return "Live TV"
        case .search: return "Search"
        case .settings: return "Settings"
        }
    }

    var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .movies: return "film"
        case .tvShows: return "tv"
        case .liveTV: return "antenna.radiowaves.left.and.right"
        case .search: return "magnifyingglass"
        case .settings: return "gearshape"
        }
    }
}
