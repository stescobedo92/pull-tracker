import Foundation

/// Represents a GitHub Pull Request with essential display information.
struct PullRequest: Identifiable, Hashable {
    let id: Int
    let number: Int
    let title: String
    let state: State
    let isDraft: Bool
    let repositoryName: String
    let repositoryOwner: String
    let ownerAvatarURL: URL?
    let commentsCount: Int
    let htmlURL: URL
    let createdAt: Date
    let updatedAt: Date
    let author: String
    
    enum State: String, CaseIterable {
        case open
        case closed
        case merged
        
        var displayName: String {
            switch self {
            case .open: return "Open"
            case .closed: return "Closed"
            case .merged: return "Merged"
            }
        }
    }
}

// MARK: - Display Helpers

extension PullRequest {
    /// Returns the full repository path (owner/repo).
    var repositoryFullName: String {
        "\(repositoryOwner)/\(repositoryName)"
    }
    
    /// Returns a relative time string for when the PR was created.
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

// MARK: - Grouped PRs

extension Array where Element == PullRequest {
    /// Groups PRs by repository for display.
    func groupedByRepository() -> [(repository: String, prs: [PullRequest])] {
        let grouped = Dictionary(grouping: self) { $0.repositoryFullName }
        return grouped
            .map { (repository: $0.key, prs: $0.value) }
            .sorted { $0.repository < $1.repository }
    }
}
