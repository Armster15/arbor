import Foundation

enum SearchProvider: String, Codable, Hashable, CaseIterable {
    case youtube
    case soundcloud
}

extension SearchProvider {
    var displayName: String {
        switch self {
        case .youtube:
            return "YouTube Music"
        case .soundcloud:
            return "SoundCloud"
        }
    }

    var symbolName: String {
        switch self {
        case .youtube:
            return "play.rectangle.fill"
        case .soundcloud:
            return "cloud.fill"
        }
    }
}
