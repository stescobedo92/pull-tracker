import Foundation
import SwiftUI

/// Filter options for Pull Requests
enum PRFilter: String, CaseIterable {
    case all = "All"
    case open = "Open"
    case merged = "Merged"
    case closed = "Closed"
    case draft = "Draft"
}

/// ViewModel for the PR list, managing state and background refresh.
@MainActor
final class PRListViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var pullRequests: [PullRequest] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var currentUser: GitHubUser?
    @Published var isAuthenticated = false
    @Published var selectedFilter: PRFilter = .all
    @Published var searchQuery: String = ""
    
    // MARK: - Dependencies
    
    private let gitHubService = GitHubService()
    private let keychainManager = KeychainManager.shared
    
    // MARK: - Background Refresh
    
    private var refreshTimer: Timer?
    private var isAppVisible = true
    
    /// Refresh interval when app is visible (2 minutes).
    private let activeRefreshInterval: TimeInterval = 120
    
    /// Refresh interval when app is in background (10 minutes).
    private let backgroundRefreshInterval: TimeInterval = 600
    
    // MARK: - Initialization
    
    init() {
        Task {
            await loadSavedCredentials()
        }
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    // MARK: - Authentication
    
    /// Attempts to load credentials from Keychain.
    func loadSavedCredentials() async {
        let hasCredentials = await gitHubService.loadSavedCredentials()
        
        if hasCredentials {
            isAuthenticated = true
            await refresh()
            startBackgroundRefresh()
        }
    }
    
    /// Authenticates with a Personal Access Token.
    /// - Parameter token: The GitHub PAT.
    func authenticate(with token: String) async {
        isLoading = true
        error = nil
        
        do {
            try keychainManager.save(token: token, for: KeychainManager.Account.gitHubToken)
            await gitHubService.configure(with: token)
            
            // Validate the token by fetching user info
            let user = try await gitHubService.getCurrentUser()
            
            // Validate token has required scopes
            let scopeError = await gitHubService.validateTokenScopes()
            if let scopeError = scopeError {
                self.error = scopeError
                try? keychainManager.delete(for: KeychainManager.Account.gitHubToken)
                isLoading = false
                return
            }
            
            currentUser = user
            isAuthenticated = true
            error = nil
            
            await refresh()
            startBackgroundRefresh()
        } catch {
            self.error = "Authentication failed: \(error.localizedDescription)"
            isAuthenticated = false
            try? keychainManager.delete(for: KeychainManager.Account.gitHubToken)
        }
        
        isLoading = false
    }
    
    /// Signs out and clears credentials.
    func signOut() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        
        try? keychainManager.delete(for: KeychainManager.Account.gitHubToken)
        
        pullRequests = []
        currentUser = nil
        isAuthenticated = false
        lastUpdated = nil
        error = nil
    }
    
    // MARK: - Data Fetching
    
    /// Manually refreshes the PR list.
    func refresh() async {
        guard isAuthenticated else { return }
        
        isLoading = true
        error = nil
        
        do {
            pullRequests = try await gitHubService.fetchMyPullRequests()
            lastUpdated = Date()
        } catch let githubError as GitHubError {
            error = githubError.errorDescription
            // Auto sign out on authentication errors
            if githubError.errorDescription?.contains("401") == true {
                signOut()
            }
        } catch {
            self.error = error.localizedDescription
            // Auto sign out on 401 errors
            if error.localizedDescription.contains("401") {
                signOut()
            }
        }
        
        isLoading = false
    }
    
    // MARK: - Background Refresh
    
    /// Updates visibility state and adjusts refresh frequency.
    func setAppVisibility(_ visible: Bool) {
        isAppVisible = visible
        restartRefreshTimer()
    }
    
    private func startBackgroundRefresh() {
        restartRefreshTimer()
    }
    
    private func restartRefreshTimer() {
        refreshTimer?.invalidate()
        
        let interval = isAppVisible ? activeRefreshInterval : backgroundRefreshInterval
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Returns the count of open PRs.
    var openPRCount: Int {
        pullRequests.filter { $0.state == .open && !$0.isDraft }.count
    }
    
    /// Returns the count of merged PRs.
    var mergedPRCount: Int {
        pullRequests.filter { $0.state == .merged }.count
    }
    
    /// Returns the count of closed PRs (not merged).
    var closedPRCount: Int {
        pullRequests.filter { $0.state == .closed }.count
    }
    
    /// Returns the dominant PR state for badge coloring.
    var dominantState: PullRequest.State {
        let counts = [
            (PullRequest.State.open, openPRCount),
            (PullRequest.State.merged, mergedPRCount),
            (PullRequest.State.closed, closedPRCount)
        ]
        return counts.max(by: { $0.1 < $1.1 })?.0 ?? .open
    }
    
    /// Returns the count of the dominant state.
    var dominantCount: Int {
        switch dominantState {
        case .open: return openPRCount
        case .merged: return mergedPRCount
        case .closed: return closedPRCount
        }
    }
    
    /// Returns PRs filtered by the selected filter and search query.
    var filteredPullRequests: [PullRequest] {
        var result: [PullRequest]
        
        switch selectedFilter {
        case .all:
            result = pullRequests
        case .open:
            result = pullRequests.filter { $0.state == .open && !$0.isDraft }
        case .merged:
            result = pullRequests.filter { $0.state == .merged }
        case .closed:
            result = pullRequests.filter { $0.state == .closed }
        case .draft:
            result = pullRequests.filter { $0.isDraft }
        }
        
        // Apply search filter if query is not empty
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            result = result.filter { pr in
                // Search by PR number (ID)
                if let number = Int(searchQuery), pr.number == number {
                    return true
                }
                // Search by title
                if pr.title.lowercased().contains(query) {
                    return true
                }
                // Search by repository name
                if pr.repositoryName.lowercased().contains(query) {
                    return true
                }
                return false
            }
        }
        
        return result
    }
    
    /// Returns filtered PRs grouped by repository.
    var groupedPullRequests: [(repository: String, prs: [PullRequest])] {
        filteredPullRequests.groupedByRepository()
    }
    
    /// Formats the last updated time for display.
    var lastUpdatedText: String {
        guard let lastUpdated else { return "Never" }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastUpdated, relativeTo: Date())
    }
}
