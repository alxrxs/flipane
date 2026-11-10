import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var controller = SwitcherController()
    private var interceptor: KeyInterceptor?
    private var statusItem: NSStatusItem!
    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
    private let allDisplaysItem = NSMenuItem(title: "Windows on All Displays", action: #selector(toggleAllDisplays), keyEquivalent: "")
    private let allDesktopsItem = NSMenuItem(title: "Windows on All Desktops", action: #selector(toggleAllDesktops), keyEquivalent: "")
    private var permissionTimer: Timer?
    private var signalSources: [DispatchSourceSignal] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        _ = controller // builds and prewarms the panel
        restoreNativeSwitcherOnSignals()

        if AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary) {
            start()
        } else {
            setStatus("Waiting for Accessibility permission…")
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
                guard AXIsProcessTrusted() else { return }
                timer.invalidate()
                self?.start()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        NativeSwitcher.setEnabled(true)
    }

    private func start() {
        let interceptor = KeyInterceptor { [controller] action in controller.handle(action) }
        guard interceptor.start() else {
            setStatus("Couldn't capture ⌘Tab — check Accessibility permission")
            return
        }
        self.interceptor = interceptor
        controller.onDismiss = { [weak interceptor] in interceptor?.reset() }
        FocusTracker.shared.start()
        NativeSwitcher.setEnabled(false)
        setStatus("⌘Tab switches windows")
    }

    // MARK: - Menu bar

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.stack", accessibilityDescription: "Flipane")

        let menu = NSMenu()
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())
        allDisplaysItem.target = self
        allDisplaysItem.state = Preferences.allDisplays ? .on : .off
        menu.addItem(allDisplaysItem)
        allDesktopsItem.target = self
        allDesktopsItem.state = Preferences.allDesktops ? .on : .off
        menu.addItem(allDesktopsItem)
        menu.addItem(.separator())
        loginItem.target = self
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(loginItem)
        let settings = NSMenuItem(title: "Accessibility Settings…", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Flipane", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func setStatus(_ text: String) {
        statusLine.title = text
    }

    @objc private func toggleAllDisplays() {
        Preferences.allDisplays.toggle()
        allDisplaysItem.state = Preferences.allDisplays ? .on : .off
    }

    @objc private func toggleAllDesktops() {
        Preferences.allDesktops.toggle()
        allDesktopsItem.state = Preferences.allDesktops ? .on : .off
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Flipane: launch at login change failed: \(error)")
        }
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    /// `kill`/logout must give ⌘Tab back to the system, so route signals through a normal quit.
    private func restoreNativeSwitcherOnSignals() {
        for sig in [SIGTERM, SIGINT, SIGHUP] {
            signal(sig, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            source.setEventHandler { NSApp.terminate(nil) }
            source.resume()
            signalSources.append(source)
        }
    }
}
