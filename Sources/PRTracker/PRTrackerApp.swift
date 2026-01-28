import SwiftUI
import AppKit

/// Main application entry point using MenuBarExtra for native Menu Bar integration.
@main
struct PRTrackerApp: App {
    @StateObject private var viewModel = PRListViewModel()
    
    var body: some Scene {
        // Menu Bar Extra (macOS 13+)
        MenuBarExtra {
            PRListView(viewModel: viewModel)
        } label: {
            MenuBarLabel(
                count: viewModel.filteredPullRequests.count,
                totalCount: viewModel.pullRequests.count,
                selectedFilter: viewModel.selectedFilter
            )
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - Menu Bar Label

struct MenuBarLabel: View {
    let count: Int
    let totalCount: Int
    let selectedFilter: PRFilter
    
    private var iconColor: NSColor {
        switch selectedFilter {
        case .all: return .labelColor
        case .open: return .systemGreen
        case .merged: return .systemPurple
        case .closed: return .systemRed
        case .draft: return .systemGray
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            // Colored PR icon using NSImage
            Image(nsImage: createPRIcon(color: iconColor))
            
            if totalCount > 0 {
                Text("\(count)")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundColor(Color(iconColor))
            }
        }
    }
    
    /// Creates a GitHub-style PR icon as NSImage with the specified color
    private func createPRIcon(color: NSColor) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let lineWidth: CGFloat = 1.6
            let circleRadius: CGFloat = 2.2
            
            color.setStroke()
            
            // Top-left circle (source)
            let topLeftCenter = NSPoint(x: 4.5, y: 14)
            let topLeftPath = NSBezierPath(ovalIn: NSRect(
                x: topLeftCenter.x - circleRadius,
                y: topLeftCenter.y - circleRadius,
                width: circleRadius * 2,
                height: circleRadius * 2
            ))
            topLeftPath.lineWidth = lineWidth
            topLeftPath.stroke()
            
            // Bottom-left circle (target)
            let bottomLeftCenter = NSPoint(x: 4.5, y: 4)
            let bottomLeftPath = NSBezierPath(ovalIn: NSRect(
                x: bottomLeftCenter.x - circleRadius,
                y: bottomLeftCenter.y - circleRadius,
                width: circleRadius * 2,
                height: circleRadius * 2
            ))
            bottomLeftPath.lineWidth = lineWidth
            bottomLeftPath.stroke()
            
            // Vertical line (left side)
            let leftLine = NSBezierPath()
            leftLine.move(to: NSPoint(x: 4.5, y: topLeftCenter.y - circleRadius))
            leftLine.line(to: NSPoint(x: 4.5, y: bottomLeftCenter.y + circleRadius))
            leftLine.lineWidth = lineWidth
            leftLine.lineCapStyle = .round
            leftLine.stroke()
            
            // Top-right circle (PR head)
            let topRightCenter = NSPoint(x: 13.5, y: 11)
            let topRightPath = NSBezierPath(ovalIn: NSRect(
                x: topRightCenter.x - circleRadius,
                y: topRightCenter.y - circleRadius,
                width: circleRadius * 2,
                height: circleRadius * 2
            ))
            topRightPath.lineWidth = lineWidth
            topRightPath.stroke()
            
            // Curved line from top-right to bottom-left
            let curvePath = NSBezierPath()
            curvePath.move(to: NSPoint(x: topRightCenter.x, y: topRightCenter.y - circleRadius))
            curvePath.curve(
                to: NSPoint(x: bottomLeftCenter.x + circleRadius, y: bottomLeftCenter.y),
                controlPoint1: NSPoint(x: 13.5, y: 5),
                controlPoint2: NSPoint(x: 10, y: 4)
            )
            curvePath.lineWidth = lineWidth
            curvePath.lineCapStyle = .round
            curvePath.stroke()
            
            return true
        }
        
        // Important: Set to original mode to preserve colors
        image.isTemplate = false
        return image
    }
}

