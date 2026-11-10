import CoreGraphics
import Foundation

/// The parts of a `CGWindowListCopyWindowInfo` entry the switcher cares about.
public struct WindowRecord: Equatable {
    public let id: CGWindowID
    public let pid: pid_t
    public let layer: Int
    public let alpha: Double
    public let bounds: CGRect

    public init(id: CGWindowID, pid: pid_t, layer: Int, alpha: Double, bounds: CGRect) {
        self.id = id
        self.pid = pid
        self.layer = layer
        self.alpha = alpha
        self.bounds = bounds
    }

    public init?(info: [String: Any]) {
        guard
            let id = info[kCGWindowNumber as String] as? NSNumber,
            let pid = info[kCGWindowOwnerPID as String] as? NSNumber,
            let layer = info[kCGWindowLayer as String] as? NSNumber,
            let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
            let bounds = CGRect(dictionaryRepresentation: boundsDict)
        else { return nil }
        let alpha = (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1
        self.init(id: id.uint32Value, pid: pid.int32Value, layer: layer.intValue, alpha: alpha, bounds: bounds)
    }
}

public enum WindowFilter {
    /// Smaller windows are almost always invisible helpers, not something you switch to.
    public static let minimumSide: CGFloat = 40

    /// Window levels that hold app windows: normal, and floating (FaceTime / Phone put their main
    /// window there). Floating palettes are rejected later by their accessibility subrole.
    public static let switchableLayers: Set<Int> = [0, 3]

    /// Keeps normal- or floating-level, visible, reasonably sized windows not owned by `excludingPID`,
    /// preserving the window server's front-to-back (most recently used) order.
    public static func candidates(from infos: [[String: Any]], excludingPID: pid_t) -> [WindowRecord] {
        infos.compactMap(WindowRecord.init(info:)).filter {
            switchableLayers.contains($0.layer)
                && $0.alpha > 0.01
                && $0.bounds.width >= minimumSide
                && $0.bounds.height >= minimumSide
                && $0.pid != excludingPID
        }
    }

    /// Whether an accessibility window is something you'd switch to. Dialogs must have a close
    /// button: AppKit's floating overlays (e.g. the Siri orb) report as untitled, buttonless
    /// dialogs on the normal window layer. A window that has a close button but keeps it hidden
    /// is an invisible stand-in some apps (Razer Synapse) leave open, not something you'd switch to;
    /// callers must not report fullscreen windows this way, since those hide their buttons too.
    public static func isSwitchable(subrole: String, hasCloseButton: Bool, hidesCloseButton: Bool = false) -> Bool {
        if hidesCloseButton { return false }
        return switch subrole {
        case "AXStandardWindow": true
        case "AXDialog": hasCloseButton
        default: false
        }
    }

    /// Keeps the windows that sit mostly on the display containing `cursor`, preserving order.
    /// All rects are in global display coordinates (top-left origin, as `CGDisplayBounds` and
    /// `kCGWindowBounds` use). If the cursor isn't on any display, nothing is filtered out.
    public static func onDisplay(_ windows: [WindowRecord], displays: [CGRect], cursor: CGPoint) -> [WindowRecord] {
        guard let target = displays.firstIndex(where: { $0.contains(cursor) }) else { return windows }
        return windows.filter { window in
            let overlaps = displays.map { area($0.intersection(window.bounds)) }
            guard let best = overlaps.indices.max(by: { overlaps[$0] < overlaps[$1] }), overlaps[best] > 0 else { return false }
            return best == target
        }
    }

    private static func area(_ rect: CGRect) -> CGFloat {
        rect.isNull ? 0 : rect.width * rect.height
    }
}
