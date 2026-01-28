import SwiftUI

/// Main view for the PR list popover.
struct PRListView: View {
    @ObservedObject var viewModel: PRListViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Search bar (when authenticated)
            if viewModel.isAuthenticated {
                searchBar
                Divider()
            }
            
            // Content
            if !viewModel.isAuthenticated {
                authenticationView
            } else if viewModel.isLoading && viewModel.pullRequests.isEmpty {
                loadingView
            } else if let error = viewModel.error, viewModel.pullRequests.isEmpty {
                errorView(error)
            } else if viewModel.pullRequests.isEmpty {
                emptyStateView
            } else if viewModel.filteredPullRequests.isEmpty {
                noFilterResultsView
            } else {
                pullRequestList
            }
        }
        .frame(width: 420, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Pull Requests")
                    .font(.headline)
                
                if viewModel.isAuthenticated {
                    Text("Updated \(viewModel.lastUpdatedText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            if viewModel.isAuthenticated {
                HStack(spacing: 12) {
                    // Filter Dropdown
                    Picker("Filter", selection: $viewModel.selectedFilter) {
                        ForEach(PRFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                    
                    // Refresh Button
                    Button(action: {
                        Task { await viewModel.refresh() }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.body.weight(.medium))
                    }
                    .buttonStyle(.borderless)
                    .disabled(viewModel.isLoading)
                    .opacity(viewModel.isLoading ? 0.5 : 1)
                    
                    // Settings Menu
                    Menu {
                        Button("Sign Out", role: .destructive) {
                            viewModel.signOut()
                        }
                        
                        Divider()
                        
                        Button("Quit PR Tracker") {
                            NSApplication.shared.terminate(nil)
                        }
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.body.weight(.medium))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search by #ID or title...", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
            
            if !viewModel.searchQuery.isEmpty {
                Button(action: { viewModel.searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .textBackgroundColor))
    }
    
    // MARK: - Authentication View
    
    @State private var tokenInput = ""
    
    @State private var showingAbout = false
    
    private var authenticationView: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 20)
            
            // Custom GitHub PR Icon (matching menu bar style)
            GitHubPRIconView(color: .purple)
                .frame(width: 60, height: 60)
            
            Text("Connect to GitHub")
                .font(.title2.weight(.semibold))
            
            Text("Enter your Personal Access Token")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 12) {
                SecureField("Paste your GitHub classic token here", text: $tokenInput)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.none)
                    .frame(width: 280)
                
                Button("Connect") {
                    Task {
                        await viewModel.authenticate(with: tokenInput)
                        if viewModel.isAuthenticated {
                            tokenInput = ""
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(tokenInput.isEmpty || viewModel.isLoading)
                .onHover { hovering in
                    if hovering && !tokenInput.isEmpty && !viewModel.isLoading {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
            
            if let error = viewModel.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            HStack {
                // About button
                Button(action: { showingAbout.toggle() }) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .popover(isPresented: $showingAbout, arrowEdge: .bottom) {
                    VStack(spacing: 8) {
                        Text("PR Tracker")
                            .font(.headline)
                        Text("Version 1.0.0")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Divider()
                        Text("Sergio Triana Escobedo")
                            .font(.caption)
                        Text("© 2026")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("All rights reserved")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(width: 200)
                }
                
                Spacer()
                
                Link("Create a new token on GitHub →", 
                     destination: URL(string: "https://github.com/settings/tokens/new?scopes=repo,read:org")!)
                    .font(.caption)
                    .onHover { hovering in
                        if hovering {
                            NSCursor.pointingHand.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - GitHub PR Icon View
    
    struct GitHubPRIconView: View {
        let color: Color
        
        var body: some View {
            Canvas { context, size in
                let width = size.width
                let height = size.height
                let lineWidth: CGFloat = 3.5
                let circleRadius: CGFloat = width * 0.1
                
                // Top-left circle (source branch)
                let topLeftCenter = CGPoint(x: width * 0.28, y: height * 0.22)
                let topLeftCircle = Path(ellipseIn: CGRect(
                    x: topLeftCenter.x - circleRadius,
                    y: topLeftCenter.y - circleRadius,
                    width: circleRadius * 2,
                    height: circleRadius * 2
                ))
                context.stroke(topLeftCircle, with: .color(color), lineWidth: lineWidth)
                
                // Bottom-left circle (target branch)
                let bottomLeftCenter = CGPoint(x: width * 0.28, y: height * 0.78)
                let bottomLeftCircle = Path(ellipseIn: CGRect(
                    x: bottomLeftCenter.x - circleRadius,
                    y: bottomLeftCenter.y - circleRadius,
                    width: circleRadius * 2,
                    height: circleRadius * 2
                ))
                context.stroke(bottomLeftCircle, with: .color(color), lineWidth: lineWidth)
                
                // Vertical line connecting top-left to bottom-left
                var leftLine = Path()
                leftLine.move(to: CGPoint(x: width * 0.28, y: topLeftCenter.y + circleRadius))
                leftLine.addLine(to: CGPoint(x: width * 0.28, y: bottomLeftCenter.y - circleRadius))
                context.stroke(leftLine, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                
                // Top-right circle (PR head)
                let topRightCenter = CGPoint(x: width * 0.72, y: height * 0.35)
                let topRightCircle = Path(ellipseIn: CGRect(
                    x: topRightCenter.x - circleRadius,
                    y: topRightCenter.y - circleRadius,
                    width: circleRadius * 2,
                    height: circleRadius * 2
                ))
                context.stroke(topRightCircle, with: .color(color), lineWidth: lineWidth)
                
                // Curved line from top-right to bottom-left (merge arrow)
                var curvePath = Path()
                curvePath.move(to: CGPoint(x: topRightCenter.x, y: topRightCenter.y + circleRadius))
                curvePath.addQuadCurve(
                    to: CGPoint(x: bottomLeftCenter.x + circleRadius, y: bottomLeftCenter.y),
                    control: CGPoint(x: width * 0.72, y: height * 0.65)
                )
                context.stroke(curvePath, with: .color(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading Pull Requests...")
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            
            Text("Something went wrong")
                .font(.headline)
            
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("Try Again") {
                Task { await viewModel.refresh() }
            }
            .buttonStyle(.bordered)
            
            Spacer()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            
            Text("All caught up!")
                .font(.title3.weight(.semibold))
            
            Text("You don't have any Pull Requests.")
                .font(.body)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
    }
    
    // MARK: - No Filter Results
    
    private var noFilterResultsView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No \(viewModel.selectedFilter.rawValue) PRs")
                .font(.title3.weight(.semibold))
            
            Text("Try selecting a different filter.")
                .font(.body)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
    }
    
    // MARK: - PR List
    
    private var pullRequestList: some View {
        ScrollView {
            LazyVStack(spacing: 8, pinnedViews: [.sectionHeaders]) {
                ForEach(viewModel.groupedPullRequests, id: \.repository) { group in
                    Section {
                        ForEach(group.prs) { pr in
                            PRRowView(pullRequest: pr)
                                .onTapGesture {
                                    NSWorkspace.shared.open(pr.htmlURL)
                                }
                        }
                    } header: {
                        repositoryHeader(group.repository)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
    
    private func repositoryHeader(_ name: String) -> some View {
        HStack {
            Image(systemName: "folder")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Preview

#Preview {
    let viewModel = PRListViewModel()
    return PRListView(viewModel: viewModel)
}
