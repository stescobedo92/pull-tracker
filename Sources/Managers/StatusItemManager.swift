import AppKit
import SwiftUI

/// Manages the Menu Bar status item lifecycle.
/// This class provides more control over the status item if needed beyond MenuBarExtra.
@MainActor
final class StatusItemManager: NSObject {
    
    static let shared = StatusItemManager()
    
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var viewModel: PRListViewModel?
    private var eventMonitor: Any?
    
    private override init() {
        super.init()
    }
    
    // MARK: - Setup
    
    /// Configures and shows the Menu Bar status item.
    /// - Parameter viewModel: The view model for the PR list.
    func setup(with viewModel: PRListViewModel) {
        self.viewModel = viewModel
        
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // Use template image for proper dark/light mode support
            let image = NSImage(systemSymbolName: "arrow.triangle.pull", accessibilityDescription: "Pull Requests")
            image?.isTemplate = true
            button.image = image
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // Create popover
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 420, height: 500)
        popover?.behavior = .transient
        popover?.animates = true
        popover?.contentViewController = NSHostingController(rootView: PRListView(viewModel: viewModel))
        
        // Monitor for clicks outside to close popover
        setupEventMonitor()
    }
    
    // MARK: - Actions
    
    @objc private func togglePopover() {
        guard let button = statusItem?.button,
              let popover = popover else { return }
        
        if popover.isShown {
            popover.performClose(nil)
            viewModel?.setAppVisibility(false)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            viewModel?.setAppVisibility(true)
        }
    }
    
    // MARK: - Event Monitor
    
    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let popover = self?.popover, popover.isShown {
                popover.performClose(nil)
                self?.viewModel?.setAppVisibility(false)
            }
        }
    }
    
    // MARK: - Badge
    
    /// Updates the status item with a badge count.
    /// - Parameter count: The number of open PRs.
    func updateBadge(count: Int) {
        guard let button = statusItem?.button else { return }
        
        if count > 0 {
            button.title = " \(count)"
        } else {
            button.title = ""
        }
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        statusItem = nil
        popover = nil
    }
    
}
