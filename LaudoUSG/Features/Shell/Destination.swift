import Foundation

enum AppDestination: Hashable {
    case computer
    case history
    case reportDetail(id: String)
    case analytics
    case library
    case settings
    case about
}
