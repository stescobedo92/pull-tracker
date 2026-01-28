import SwiftUI

/// Individual row displaying a Pull Request with avatar, title, status badge, and comment count.
struct PRRowView: View {
    let pullRequest: PullRequest
    
    var body: some View {
        HStack(spacing: 12) {
            // Owner Avatar
            AsyncImage(url: pullRequest.ownerAvatarURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Image(systemName: "person.circle.fill")
                        .foregroundStyle(.secondary)
                case .empty:
                    ProgressView()
                        .scaleEffect(0.5)
                @unknown default:
                    Image(systemName: "person.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
            
            // Title and Repo Info
            VStack(alignment: .leading, spacing: 4) {
                Text(pullRequest.title)
                    .font(.system(.body, design: .default, weight: .medium))
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                
                HStack(spacing: 6) {
                    Text("#\(pullRequest.number)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                    
                    Text(pullRequest.repositoryFullName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                    
                    Text(pullRequest.timeAgo)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            
            Spacer()
            
            // Right side: Status badge and comments
            VStack(alignment: .trailing, spacing: 6) {
                // Status Badge
                StatusBadge(state: pullRequest.state, isDraft: pullRequest.isDraft)
                
                // Comment Count
                if pullRequest.commentsCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "bubble.right")
                            .font(.caption2)
                        Text("\(pullRequest.commentsCount)")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let state: PullRequest.State
    let isDraft: Bool
    
    var body: some View {
        Text(displayText)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
    }
    
    private var displayText: String {
        if isDraft {
            return "Draft"
        }
        return state.displayName
    }
    
    private var backgroundColor: Color {
        if isDraft {
            return Color.gray.opacity(0.2)
        }
        switch state {
        case .open:
            return Color.green.opacity(0.2)
        case .merged:
            return Color.purple.opacity(0.2)
        case .closed:
            return Color.red.opacity(0.2)
        }
    }
    
    private var textColor: Color {
        if isDraft {
            return .gray
        }
        switch state {
        case .open:
            return .green
        case .merged:
            return .purple
        case .closed:
            return .red
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 8) {
        PRRowView(pullRequest: PullRequest(
            id: 1,
            number: 123,
            title: "Add new authentication flow with OAuth 2.0 support",
            state: .open,
            isDraft: false,
            repositoryName: "awesome-app",
            repositoryOwner: "octocat",
            ownerAvatarURL: URL(string: "https://github.com/octocat.png"),
            commentsCount: 5,
            htmlURL: URL(string: "https://github.com/octocat/awesome-app/pull/123")!,
            createdAt: Date().addingTimeInterval(-3600),
            updatedAt: Date(),
            author: "octocat"
        ))
        
        PRRowView(pullRequest: PullRequest(
            id: 2,
            number: 456,
            title: "WIP: Refactor database layer",
            state: .open,
            isDraft: true,
            repositoryName: "core-lib",
            repositoryOwner: "myorg",
            ownerAvatarURL: nil,
            commentsCount: 0,
            htmlURL: URL(string: "https://github.com/myorg/core-lib/pull/456")!,
            createdAt: Date().addingTimeInterval(-86400),
            updatedAt: Date(),
            author: "developer"
        ))
    }
    .padding()
    .frame(width: 400)
}
