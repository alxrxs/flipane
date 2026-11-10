import ApplicationServices
import Darwin

/// Undocumented system calls, resolved at runtime so a missing symbol degrades
/// gracefully instead of failing to launch.
enum PrivateAPI {
    typealias SetSymbolicHotKeyEnabled = @convention(c) (Int32, Bool) -> Int32
    typealias AXGetWindow = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
    typealias GetProcessForPID = @convention(c) (pid_t, UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus
    typealias SetFrontProcessWithOptions = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, CGWindowID, UInt32) -> Int32
    typealias PostEventRecordTo = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, UnsafeMutablePointer<UInt8>) -> Int32
    typealias MainConnectionID = @convention(c) () -> Int32
    typealias CopySpacesForWindows = @convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?
    typealias WindowIsOrderedIn = @convention(c) (Int32, CGWindowID, UnsafeMutablePointer<UInt8>) -> Int32
    typealias AXCreateWithRemoteToken = @convention(c) (CFData) -> Unmanaged<AXUIElement>?

    private static let skyLight: Void = {
        _ = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
    }()

    private static func resolve<T>(_ name: String, as _: T.Type) -> T? {
        _ = skyLight
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) else { return nil } // RTLD_DEFAULT
        return unsafeBitCast(symbol, to: T.self)
    }

    static let setSymbolicHotKeyEnabled = resolve("CGSSetSymbolicHotKeyEnabled", as: SetSymbolicHotKeyEnabled.self)
    static let axGetWindow = resolve("_AXUIElementGetWindow", as: AXGetWindow.self)
    static let getProcessForPID = resolve("GetProcessForPID", as: GetProcessForPID.self)
    static let setFrontProcessWithOptions = resolve("_SLPSSetFrontProcessWithOptions", as: SetFrontProcessWithOptions.self)
    static let postEventRecordTo = resolve("SLPSPostEventRecordTo", as: PostEventRecordTo.self)
    static let mainConnectionID = resolve("SLSMainConnectionID", as: MainConnectionID.self)
    static let copySpacesForWindows = resolve("SLSCopySpacesForWindows", as: CopySpacesForWindows.self)
    static let windowIsOrderedIn = resolve("SLSWindowIsOrderedIn", as: WindowIsOrderedIn.self)
    static let axCreateWithRemoteToken = resolve("_AXUIElementCreateWithRemoteToken", as: AXCreateWithRemoteToken.self)
}

/// Turns the system's own ⌘Tab / ⇧⌘Tab app switcher on or off.
enum NativeSwitcher {
    private static let commandTab: Int32 = 1
    private static let commandShiftTab: Int32 = 2

    static func setEnabled(_ enabled: Bool) {
        guard let set = PrivateAPI.setSymbolicHotKeyEnabled else { return }
        _ = set(commandTab, enabled)
        _ = set(commandShiftTab, enabled)
    }
}
