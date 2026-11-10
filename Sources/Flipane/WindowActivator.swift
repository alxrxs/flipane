import AppKit

/// Brings one specific window to the front, not just its app.
enum WindowActivator {
    private static let userGenerated: UInt32 = 0x200

    static func focus(_ window: SwitchableWindow) {
        var psn = ProcessSerialNumber()
        if let getPSN = PrivateAPI.getProcessForPID,
           let setFront = PrivateAPI.setFrontProcessWithOptions,
           getPSN(window.pid, &psn) == noErr {
            _ = setFront(&psn, window.id, userGenerated)
            makeKeyWindow(&psn, window.id)
        } else {
            NSRunningApplication(processIdentifier: window.pid)?.activate()
        }
        AXUIElementSetAttributeValue(window.element, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(window.element, kAXRaiseAction as CFString)
    }

    /// Posts the window-server event that makes `windowID` the key window of its process.
    private static func makeKeyWindow(_ psn: inout ProcessSerialNumber, _ windowID: CGWindowID) {
        guard let post = PrivateAPI.postEventRecordTo else { return }
        var bytes = [UInt8](repeating: 0, count: 0xf8)
        bytes[0x04] = 0xf8
        bytes[0x3a] = 0x10
        withUnsafeBytes(of: windowID) { bytes.replaceSubrange(0x3c..<0x40, with: $0) }
        bytes.replaceSubrange(0x20..<0x30, with: repeatElement(0xff, count: 0x10))
        bytes[0x08] = 0x01
        _ = post(&psn, &bytes)
        bytes[0x08] = 0x02
        _ = post(&psn, &bytes)
    }
}
