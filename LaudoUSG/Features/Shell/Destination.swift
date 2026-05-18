import Foundation

enum AppDestination: Hashable {
    case history
    case reportDetail(id: String)
    case analytics
    case library
    case settings
    case about
}
