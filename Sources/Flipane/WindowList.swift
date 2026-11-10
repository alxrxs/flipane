import AppKit
import FlipaneCore

struct SwitchableWindow {
    let id: CGWindowID
    let pid: pid_t
    let title: String
    let appName: String
    let icon: NSImage?
    let element: AXUIElement
}

/// Windows most recently used first: those on the current Space of the
/// cursor's display by default, widened to every display and/or every Space by `Preferences`.
/// Minimized windows and windows of hidden apps never appear.
enum WindowList {
    /// Elements found by the slow remote-token search, reused while their windows live.
    private static var remoteElements: [CGWindowID: AXUIElement] = [:]
    /// Where the remote-token search for a not-yet-found window resumes, so a search cut short
    /// by its time limit continues on the next ⌘Tab instead of starting over.
    private static var remoteSearchResume: [CGWindowID: UInt64] = [:]
    private static let remoteSearchLimit: UInt64 = 1000

    static func current() -> [SwitchableWindow] {
        let allDesktops = Preferences.allDesktops
        let options: CGWindowListOption = allDesktops ? [.optionAll, .excludeDesktopElements] : [.optionOnScreenOnly, .excludeDesktopElements]
        let infos = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        let onscreen = Set(infos.compactMap { info -> CGWindowID? in
            guard info[kCGWindowIsOnscreen as String] as? Bool == true else { return nil }
            return (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value
        })
        var axWindowsByPID: [pid_t: [CGWindowID: AXUIElement]] = [:]
        var windows: [SwitchableWindow] = []

        var candidates = WindowFilter.candidates(from: infos, excludingPID: getpid())
        if allDesktops {
            // Off-screen windows are on other Spaces, minimized, closed but kept alive (⌘W in
            // Claude, Notes), or never-shown helpers; only the first kind is ordered in on a Space.
            candidates = candidates.filter { onscreen.contains($0.id) || (isOrderedIn($0.id) && isOnSomeSpace($0.id)) }
        }
        if !Preferences.allDisplays {
            candidates = WindowFilter.onDisplay(candidates, displays: activeDisplayBounds(), cursor: CGEvent(source: nil)?.location ?? .zero)
        }
        var missingByPID: [pid_t: Set<CGWindowID>] = [:]
        if allDesktops {
            for record in candidates where !onscreen.contains(record.id) {
                missingByPID[record.pid, default: []].insert(record.id)
            }
        }
        let offscreenIDs = missingByPID.values.reduce(into: Set<CGWindowID>()) { $0.formUnion($1) }
        remoteElements = remoteElements.filter { offscreenIDs.contains($0.key) }
        remoteSearchResume = remoteSearchResume.filter { offscreenIDs.contains($0.key) }

        for record in candidates {
            guard let app = NSRunningApplication(processIdentifier: record.pid),
                  app.activationPolicy == .regular,
                  onscreen.contains(record.id) || !app.isHidden else { continue }

            let pidWindows = axWindowsByPID[record.pid] ?? {
                var found = axWindows(of: record.pid)
                // AXWindows leaves out windows on other Spaces; dig those up separately.
                let missing = (missingByPID[record.pid] ?? []).subtracting(found.keys)
                if !missing.isEmpty { found.merge(remoteWindows(of: record.pid, ids: missing)) { current, _ in current } }
                axWindowsByPID[record.pid] = found
                return found
            }()
            guard let element = pidWindows[record.id],
                  onscreen.contains(record.id) || !isMinimized(element),
                  let subrole = string(element, kAXSubroleAttribute),
                  WindowFilter.isSwitchable(subrole: subrole, hasCloseButton: closeButton(of: element) != nil, hidesCloseButton: hidesCloseButton(element))
            else { continue }

            let appName = app.localizedName ?? ""
            let title = string(element, kAXTitleAttribute) ?? ""
            windows.append(SwitchableWindow(
                id: record.id,
                pid: record.pid,
                title: title.isEmpty ? appName : title,
                appName: appName,
                icon: app.icon,
                element: element
            ))
        }
        return FocusTracker.shared.history.sorted(windows, by: \.id)
    }

    /// Bounds of every active display, in the same top-left-origin space as window bounds.
    private static func activeDisplayBounds() -> [CGRect] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
        return ids.prefix(Int(count)).map(CGDisplayBounds)
    }

    private static func axWindows(of pid: pid_t) -> [CGWindowID: AXUIElement] {
        let app = AXUIElementCreateApplication(pid)
        // A hung app must not stall the switcher.
        AXUIElementSetMessagingTimeout(app, 0.15)
        guard let elements = array(app, kAXWindowsAttribute),
              let getWindow = PrivateAPI.axGetWindow else { return [:] }
        // Some apps (Finder) report an empty AXWindows even though their windows are listed
        // among the app's children, so look there too.
        let children = (array(app, kAXChildrenAttribute) ?? []).filter { string($0, kAXRoleAttribute) == kAXWindowRole }

        var result: [CGWindowID: AXUIElement] = [:]
        for element in elements + children {
            var id: CGWindowID = 0
            if getWindow(element, &id) == .success, result[id] == nil { result[id] = element }
        }
        return result
    }

    private static func isOrderedIn(_ id: CGWindowID) -> Bool {
        guard let connection = PrivateAPI.mainConnectionID?(),
              let orderedIn = PrivateAPI.windowIsOrderedIn else { return true }
        var result: UInt8 = 0
        return orderedIn(connection, id, &result) != 0 || result != 0
    }

    private static func isOnSomeSpace(_ id: CGWindowID) -> Bool {
        guard let connection = PrivateAPI.mainConnectionID?(),
              let copySpaces = PrivateAPI.copySpacesForWindows,
              let spaces = copySpaces(connection, 0x7 /* all spaces */, [NSNumber(value: id)] as CFArray)?.takeRetainedValue()
        else { return false }
        return CFArrayGetCount(spaces) > 0
    }

    /// Finds `ids` among the app's accessibility elements by probing element IDs directly,
    /// which also reaches windows on other Spaces. Bounded in time so a large app can't stall us.
    private static func remoteWindows(of pid: pid_t, ids: Set<CGWindowID>) -> [CGWindowID: AXUIElement] {
        var result: [CGWindowID: AXUIElement] = [:]
        var remaining = ids
        for id in ids {
            guard let element = remoteElements[id] else { continue }
            var actual: CGWindowID = 0
            if PrivateAPI.axGetWindow?(element, &actual) == .success, actual == id {
                result[id] = element
                remaining.remove(id)
            } else {
                remoteElements[id] = nil
            }
        }
        // Windows whose whole search range came up empty aren't reachable this way.
        remaining = remaining.filter { remoteSearchResume[$0, default: 0] < remoteSearchLimit }
        guard !remaining.isEmpty,
              let create = PrivateAPI.axCreateWithRemoteToken,
              let getWindow = PrivateAPI.axGetWindow else { return result }

        // Token layout: pid, 0, 'coco', then the 64-bit element ID.
        var token = Data(count: 20)
        token.withUnsafeMutableBytes { bytes in
            bytes.storeBytes(of: pid, toByteOffset: 0, as: Int32.self)
            bytes.storeBytes(of: 0x636f_636f, toByteOffset: 8, as: Int32.self)
        }
        let deadline = Date().addingTimeInterval(0.1)
        var elementID = remaining.map { remoteSearchResume[$0, default: 0] }.min() ?? 0
        defer { for id in remaining { remoteSearchResume[id] = elementID } }
        while elementID < remoteSearchLimit, !remaining.isEmpty, Date() < deadline {
            defer { elementID += 1 }
            token.withUnsafeMutableBytes { $0.storeBytes(of: elementID, toByteOffset: 12, as: UInt64.self) }
            guard let element = create(token as CFData)?.takeRetainedValue() else { continue }
            AXUIElementSetMessagingTimeout(element, 0.15)
            var id: CGWindowID = 0
            guard getWindow(element, &id) == .success, remaining.contains(id),
                  let window = windowElement(containing: element, id: id, getWindow: getWindow) else { continue }
            remaining.remove(id)
            result[id] = window
            remoteElements[id] = window
            remoteSearchResume[id] = nil
        }
        return result
    }

    /// Every element inside a window (buttons, scroll areas…) reports that window's ID, and the
    /// window element itself is sometimes unreachable by token, so climb from whatever we hit.
    private static func windowElement(containing element: AXUIElement, id: CGWindowID, getWindow: PrivateAPI.AXGetWindow) -> AXUIElement? {
        if string(element, kAXRoleAttribute) == kAXWindowRole { return element }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXWindowAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        let window = value as! AXUIElement
        var windowID: CGWindowID = 0
        return getWindow(window, &windowID) == .success && windowID == id ? window : nil
    }

    private static func closeButton(of element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXCloseButtonAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    /// A hidden button is left out of its window's children. Fullscreen windows hide theirs too.
    private static func hidesCloseButton(_ element: AXUIElement) -> Bool {
        guard let button = closeButton(of: element) else { return false }
        var fullScreen: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, "AXFullScreen" as CFString, &fullScreen) == .success,
           (fullScreen as? Bool) == true { return false }
        guard let children = array(element, kAXChildrenAttribute) else { return false }
        return !children.contains { CFEqual($0, button) }
    }

    private static func isMinimized(_ element: AXUIElement) -> Bool {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, kAXMinimizedAttribute as CFString, &value) == .success
            && (value as? Bool) == true
    }

    private static func array(_ element: AXUIElement, _ attribute: String) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? [AXUIElement]
    }

    private static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }
}
