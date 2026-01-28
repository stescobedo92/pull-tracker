import Foundation
import OctoKit

/// Service layer for interacting with the GitHub API via OctoKit.
/// Uses async/await for all network operations.
actor GitHubService {
    
    private var octokit: Octokit?
    private var token: String?  // Store token for direct API calls
    private let keychainManager = KeychainManager.shared
    
    /// Rate limit information from the last API call.
    private(set) var rateLimitRemaining: Int = 60
    private(set) var rateLimitReset: Date?
    
    // MARK: - Configuration
    
    /// Configures the service with a Personal Access Token.
    /// - Parameter token: The GitHub PAT.
    func configure(with token: String) {
        self.token = token
        let config = TokenConfiguration(token)
        self.octokit = Octokit(config)
    }
    
    /// Attempts to load saved credentials from Keychain.
    /// - Returns: `true` if credentials were loaded successfully.
    func loadSavedCredentials() -> Bool {
        guard let token = keychainManager.retrieve(for: KeychainManager.Account.gitHubToken) else {
            return false
        }
        configure(with: token)
        return true
    }
    
    /// Checks if the service is configured with valid credentials.
    var isAuthenticated: Bool {
        octokit != nil
    }
    
    // MARK: - API Methods
    
    /// Fetches the authenticated user's information.
    /// - Returns: The `GitHubUser` if successful.
    /// - Throws: `GitHubError` if the request fails.
    func getCurrentUser() async throws -> GitHubUser {
        guard let octokit = octokit else {
            throw GitHubError.notAuthenticated
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            octokit.me { response in
                switch response {
                case .success(let user):
                    let githubUser = GitHubUser(
                        id: user.id,
                        login: user.login ?? "unknown",
                        name: user.name,
                        avatarURL: URL(string: user.avatarURL ?? "")
                    )
                    continuation.resume(returning: githubUser)
                case .failure(let error):
                    continuation.resume(throwing: GitHubError.apiError(error))
                }
            }
        }
    }
    
    /// Validates that the token has the required scopes for the app to function.
    /// Makes a request to GitHub API and checks the X-OAuth-Scopes header.
    /// - Returns: An error message if scopes are missing, nil if all required scopes are present.
    func validateTokenScopes() async -> String? {
        guard let token = token else { return "Token not configured" }
        
        var request = URLRequest(url: URL(string: "https://api.github.com/user")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return "Invalid response from GitHub"
            }
            
            // Check for required scopes in the response header
            let scopesHeader = httpResponse.value(forHTTPHeaderField: "X-OAuth-Scopes") ?? ""
            let scopes = scopesHeader.lowercased().split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            
            // Required scopes for the app
            let requiredScopes = ["repo"]
            var missingScopes: [String] = []
            
            for required in requiredScopes {
                // Check if scope is present (or if "repo" covers sub-scopes)
                let hasScope = scopes.contains { scope in
                    scope == required || scope.hasPrefix(required)
                }
                if !hasScope {
                    missingScopes.append(required)
                }
            }
            
            // Also check for read:org (recommended but not required)
            let hasOrgRead = scopes.contains { $0 == "read:org" || $0 == "admin:org" }
            
            if !missingScopes.isEmpty {
                return "⚠️ Missing required permissions:\n\n" +
                       "• \(missingScopes.joined(separator: "\n• "))\n\n" +
                       "Please create a new token with:\n" +
                       "✓ repo (Full control of repositories)\n" +
                       "✓ read:org (Read organization data)"
            }
            
            if !hasOrgRead {
                // Warning but not blocking
                print("Note: Token missing read:org scope, some features may be limited")
            }
            
            return nil
        } catch {
            return "Failed to validate token: \(error.localizedDescription)"
        }
    }
    
    /// Fetches all open pull requests for the authenticated user across all repositories.
    /// - Returns: An array of `PullRequest` objects.
    /// - Throws: `GitHubError` if the request fails.
    func fetchAllPullRequests() async throws -> [PullRequest] {
        guard let octokit = octokit else {
            throw GitHubError.notAuthenticated
        }
        
        // First, get all repositories the user can access
        let repos = try await fetchUserRepositories()
        
        // Then fetch PRs for each repository concurrently
        var allPRs: [PullRequest] = []
        
        try await withThrowingTaskGroup(of: [PullRequest].self) { group in
            for repo in repos {
                group.addTask {
                    try await self.fetchPullRequestsForRepo(
                        owner: repo.owner,
                        name: repo.name,
                        octokit: octokit
                    )
                }
            }
            
            for try await prs in group {
                allPRs.append(contentsOf: prs)
            }
        }
        
        // Sort by updated date, most recent first
        return allPRs.sorted { $0.updatedAt > $1.updatedAt }
    }
    
    /// Fetches ALL PRs authored by the authenticated user using GitHub Search API.
    /// This is more efficient than fetching per-repo and handles pagination.
    /// - Returns: An array of `PullRequest` objects.
    /// - Throws: `GitHubError` if the request fails.
    func fetchMyPullRequests() async throws -> [PullRequest] {
        guard let token = token else { throw GitHubError.notAuthenticated }
        
        let user = try await getCurrentUser()
        var allPRs: [PullRequest] = []
        var page = 1
        let perPage = 100  // Max allowed by GitHub API
        
        // Paginate through all results
        while true {
            let searchQuery = "is:pr author:\(user.login)"
            let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchQuery
            let urlString = "https://api.github.com/search/issues?q=\(encodedQuery)&per_page=\(perPage)&page=\(page)&sort=updated&order=desc"
            
            guard let url = URL(string: urlString) else { break }
            
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let searchResult = try decoder.decode(SearchIssuesResponse.self, from: data)
            
            let prs = searchResult.items.compactMap { item -> PullRequest? in
                guard let prUrl = item.pull_request?.html_url,
                      let htmlURL = URL(string: prUrl) else { return nil }
                
                // Parse repository from URL: https://github.com/owner/repo/pull/123
                let pathComponents = item.html_url.components(separatedBy: "/")
                guard pathComponents.count >= 5 else { return nil }
                let repoOwner = pathComponents[3]
                let repoName = pathComponents[4]
                
                let state: PullRequest.State
                if item.state == "closed" {
                    // Check if merged by looking at pull_request.merged_at
                    if item.pull_request?.merged_at != nil {
                        state = .merged
                    } else {
                        state = .closed
                    }
                } else {
                    state = .open
                }
                
                let isDraft = item.draft ?? false
                
                return PullRequest(
                    id: item.id,
                    number: item.number,
                    title: item.title,
                    state: state,
                    isDraft: isDraft,
                    repositoryName: repoName,
                    repositoryOwner: repoOwner,
                    ownerAvatarURL: URL(string: item.user.avatar_url),
                    commentsCount: item.comments,
                    htmlURL: htmlURL,
                    createdAt: item.created_at,
                    updatedAt: item.updated_at,
                    author: item.user.login
                )
            }
            
            allPRs.append(contentsOf: prs)
            
            // Stop if we got fewer results than requested (last page)
            if searchResult.items.count < perPage {
                break
            }
            
            page += 1
            
            // Safety limit to avoid infinite loops
            if page > 10 { break }
        }
        
        return allPRs.sorted { $0.updatedAt > $1.updatedAt }
    }
    
    // MARK: - Search API Response Models
    
    private struct SearchIssuesResponse: Decodable {
        let total_count: Int
        let items: [SearchIssueItem]
    }
    
    private struct SearchIssueItem: Decodable {
        let id: Int
        let number: Int
        let title: String
        let state: String
        let html_url: String
        let user: SearchUser
        let created_at: Date
        let updated_at: Date
        let comments: Int
        let draft: Bool?
        let pull_request: SearchPullRequest?
    }
    
    private struct SearchUser: Decodable {
        let login: String
        let avatar_url: String
    }
    
    private struct SearchPullRequest: Decodable {
        let html_url: String?
        let merged_at: Date?
    }
    
    // MARK: - Private Helpers
    
    private struct RepoInfo {
        let owner: String
        let name: String
    }
    
    private func fetchUserRepositories() async throws -> [RepoInfo] {
        guard let octokit = octokit else {
            throw GitHubError.notAuthenticated
        }
        
        // Collect repos from user's own repos AND from all organizations
        var allRepos: [RepoInfo] = []
        
        // 1. Fetch user's own repositories
        let userRepos = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[RepoInfo], Error>) in
            octokit.repositories { response in
                switch response {
                case .success(let repos):
                    let repoInfos = repos.compactMap { repo -> RepoInfo? in
                        guard let name = repo.name else { return nil }
                        let owner = repo.owner.login ?? "unknown"
                        return RepoInfo(owner: owner, name: name)
                    }
                    continuation.resume(returning: repoInfos)
                case .failure(let error):
                    continuation.resume(throwing: GitHubError.apiError(error))
                }
            }
        }
        allRepos.append(contentsOf: userRepos)
        
        // 2. Fetch user's organizations
        let orgs = try await fetchUserOrganizations(octokit: octokit)
        
        // 3. Fetch repos from each organization concurrently
        try await withThrowingTaskGroup(of: [RepoInfo].self) { group in
            for org in orgs {
                group.addTask {
                    try await self.fetchOrganizationRepos(org: org, octokit: octokit)
                }
            }
            
            for try await orgRepos in group {
                allRepos.append(contentsOf: orgRepos)
            }
        }
        
        return allRepos
    }
    
    private func fetchUserOrganizations(octokit: Octokit) async throws -> [String] {
        // Use direct API call since OctoKit doesn't have organization methods
        guard let token = token else { return [] }
        
        guard let url = URL(string: "https://api.github.com/user/orgs") else { return [] }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            
            struct OrgResponse: Decodable {
                let login: String
            }
            
            let orgs = try JSONDecoder().decode([OrgResponse].self, from: data)
            return orgs.map { $0.login }
        } catch {
            print("Could not fetch organizations: \(error)")
            return []
        }
    }
    
    private func fetchOrganizationRepos(org: String, octokit: Octokit) async throws -> [RepoInfo] {
        return try await withCheckedThrowingContinuation { continuation in
            octokit.repositories(owner: org) { response in
                switch response {
                case .success(let repos):
                    let repoInfos = repos.compactMap { repo -> RepoInfo? in
                        guard let name = repo.name else { return nil }
                        return RepoInfo(owner: org, name: name)
                    }
                    continuation.resume(returning: repoInfos)
                case .failure(let error):
                    // If we can't access org repos, just return empty
                    print("Could not fetch repos for org \(org): \(error)")
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    private func fetchPullRequestsForRepo(owner: String, name: String, octokit: Octokit) async throws -> [PullRequest] {
        return try await withCheckedThrowingContinuation { continuation in
            // Fetch ALL PRs (open, closed, merged) instead of just .open
            octokit.pullRequests(owner: owner, repository: name, state: .all) { response in
                switch response {
                case .success(let prs):
                    let pullRequests = prs.compactMap { pr -> PullRequest? in
                        guard let title = pr.title,
                              let htmlURL = pr.htmlURL else {
                            return nil
                        }
                        
                        let id = pr.id
                        let number = pr.number
                        
                        // Determine state from pr.state enum (OctoKit uses Openness enum)
                        let state: PullRequest.State
                        if pr.state == .closed {
                            state = .closed
                        } else {
                            state = .open
                        }
                        
                        return PullRequest(
                            id: id,
                            number: number,
                            title: title,
                            state: state,
                            isDraft: pr.draft ?? false,
                            repositoryName: name,
                            repositoryOwner: owner,
                            ownerAvatarURL: pr.user?.avatarURL.flatMap { URL(string: $0) },
                            commentsCount: 0, // OctoKit PullRequest doesn't expose comment count
                            htmlURL: htmlURL,
                            createdAt: pr.createdAt ?? Date(),
                            updatedAt: pr.updatedAt ?? Date(),
                            author: pr.user?.login ?? "unknown"
                        )
                    }
                    continuation.resume(returning: pullRequests)
                case .failure(let error):
                    continuation.resume(throwing: GitHubError.apiError(error))
                }
            }
        }
    }
}

// MARK: - Errors

enum GitHubError: LocalizedError {
    case notAuthenticated
    case apiError(Error)
    case rateLimited(resetDate: Date)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Please add your GitHub token."
        case .apiError(let error):
            return "GitHub API error: \(error.localizedDescription)"
        case .rateLimited(let resetDate):
            let formatter = RelativeDateTimeFormatter()
            let timeUntilReset = formatter.localizedString(for: resetDate, relativeTo: Date())
            return "Rate limited. Resets \(timeUntilReset)."
        case .invalidResponse:
            return "Invalid response from GitHub."
        }
    }
}
