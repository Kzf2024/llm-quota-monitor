import SwiftUI
import LLMQuotaMonitorKit

@main
struct LLMQuotaMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty scene body — key management window is handled by AppDelegate
        // to avoid duplicate windows and prevent app termination on close
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let service = ModelService()
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var keyManageWindow: NSWindow?
    private var titleUpdateTimer: Timer?
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        ProcessInfo.processInfo.disableAutomaticTermination("LLM Quota Monitor is running")

        // Create status bar item with tooltip
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let button = statusItem.button!
        button.title = service.statusBarTitle
        button.toolTip = service.statusBarTooltip
        button.action = #selector(togglePopover)
        button.target = self

        // Create popover with SwiftUI content
        let menuView = ModelMenuView(service: service, openKeyManageAction: { [weak self] in
            self?.openKeyManageWindow()
        })
        popover = NSPopover()
        popover.contentViewController = NSHostingController(rootView: menuView)
        popover.behavior = .transient

        // Load keys and start
        service.loadKeys()
        if service.activeKey != nil {
            Task { await service.refresh() }
        }
        service.startAutoRefresh()

        startTitleUpdateTimer()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - Popover

    @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            guard let button = statusItem.button else { return }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            startEventMonitor()
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        stopEventMonitor()
    }

    // MARK: - Event Monitor

    private func startEventMonitor() {
        // Global: clicks in other apps → always close
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
        // Local: clicks inside our app → close unless inside popover or on status bar button
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, self.popover.isShown else { return event }
            // Let status bar button clicks through (togglePopover handles them)
            if let button = self.statusItem.button {
                let screenPoint = NSEvent.mouseLocation
                let buttonFrame = button.window?.convertToScreen(button.bounds) ?? .zero
                if buttonFrame.contains(screenPoint) {
                    return event
                }
            }
            // Close if click is outside popover
            if let popoverWindow = self.popover.contentViewController?.view.window {
                let pointInPopover = popoverWindow.convertPoint(fromScreen: NSEvent.mouseLocation)
                if popoverWindow.contentView?.hitTest(pointInPopover) != nil {
                    return event // Click inside popover, keep open
                }
            }
            self.closePopover()
            return event
        }
    }

    private func stopEventMonitor() {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }

    // MARK: - Key Management Window

    private func openKeyManageWindow() {
        if let window = keyManageWindow, window.isVisible {
            NSApplication.shared.activate()
            window.makeKeyAndOrderFront(nil)
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "管理 API Key"
        window.contentView = NSHostingView(rootView: KeyManageView(service: service))
        window.center()
        NSApplication.shared.activate()
        window.makeKeyAndOrderFront(nil)
        keyManageWindow = window
    }

    // MARK: - Status Bar Title Update

    private func startTitleUpdateTimer() {
        titleUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.statusItem.button?.title = self.service.statusBarTitle
            self.statusItem.button?.toolTip = self.service.statusBarTooltip
        }
    }
}
