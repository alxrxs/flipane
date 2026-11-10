import AppKit
import FlipaneCore

/// Records every window that gains focus, in any app on any Space, so the switcher can list
/// windows most recently used first. Main thread only.
final class FocusTracker {
    static let shared = FocusTracker()

    private(set) var history = FocusHistory()
    private var observers: [pid_t: AXObserver] = [:]
    private var tokens: [NSObjectProtocol] = []

    func start() {
        guard tokens.isEmpty else { return }
        // Seed with what's on screen now, front window last so it ends up most recent.
        let infos = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        for record in WindowFilter.candidates(from: infos, excludingPID: getpid()).reversed() {
            history.touch(record.id)
        }

        for app in NSWorkspace.shared.runningApplications { observe(app) }
        let center = NSWorkspace.shared.notificationCenter
        tokens.append(center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] note in
            if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication { self?.observe(app) }
        })
        tokens.append(center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication { self?.forget(app) }
        })
        // Switching apps keeps each app's focused window, so no focus notification fires.
        tokens.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.observe(app)
            self?.touchFocusedWindow(of: app.processIdentifier)
        })
        if let front = NSWorkspace.shared.frontmostApplication { touchFocusedWindow(of: front.processIdentifier) }
    }

    func touch(_ id: CGWindowID) {
        history.touch(id)
    }

    private func observe(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard app.activationPolicy == .regular, pid != getpid(), observers[pid] == nil else { return }
        var observer: AXObserver?
        let callback: AXObserverCallback = { _, element, _, _ in
            FocusTracker.shared.touch(element)
        }
        guard AXObserverCreate(pid, callback, &observer) == .success, let observer else { return }
        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, 0.15)
        // A just-launched app may not answer yet; activating it later retries.
        guard AXObserverAddNotification(observer, element, kAXFocusedWindowChangedNotification as CFString, nil) == .success else { return }
        AXObserverAddNotification(observer, element, kAXMainWindowChangedNotification as CFString, nil)
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        observers[pid] = observer
    }

    private func forget(_ app: NSRunningApplication) {
        guard let observer = observers.removeValue(forKey: app.processIdentifier) else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }

    private func touchFocusedWindow(of pid: pid_t) {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.15)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return }
        touch(value as! AXUIElement)
    }

    private func touch(_ window: AXUIElement) {
        var id: CGWindowID = 0
        guard PrivateAPI.axGetWindow?(window, &id) == .success, id != 0 else { return }
        history.touch(id)
    }
}
