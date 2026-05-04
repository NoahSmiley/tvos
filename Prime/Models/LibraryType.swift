import Foundation

enum LibraryType {
    case movies
    case tvShows

    var jellyfinType: String {
        switch self {
        case .movies: return "Movie"
        case .tvShows: return "Series"
        }
    }

    var title: String {
        switch self {
        case .movies: return "Movies"
        case .tvShows: return "TV Shows"
        }
    }
}
