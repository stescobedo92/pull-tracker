import Foundation

/// Represents the authenticated GitHub user.
struct GitHubUser: Identifiable {
    let id: Int
    let login: String
    let name: String?
    let avatarURL: URL?
}
