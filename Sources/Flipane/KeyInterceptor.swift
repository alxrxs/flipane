import FlipaneCore
import CoreGraphics
import Foundation

/// Session-level event tap that claims ⌘Tab and everything typed while the switcher is up.
/// Runs on the main run loop; decisions are made synchronously so events are never reordered,
/// while the (slower) UI work is handed to `onAction` asynchronously.
final class KeyInterceptor {
    private let onAction: (KeyAction) -> Void
    private var tap: CFMachPort?
    private var isActive = false

    init(onAction: @escaping (KeyAction) -> Void) {
        self.onAction = onAction
    }

    func start() -> Bool {
        let mask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: keyTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        self.tap = tap
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    /// The switcher closed without a key telling us (a click): stop claiming keystrokes.
    func reset() {
        isActive = false
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let kind: KeyEventKind
        switch type {
        case .keyDown: kind = .keyDown
        case .keyUp: kind = .keyUp
        case .flagsChanged: kind = .flagsChanged
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        default:
            return Unmanaged.passUnretained(event)
        }

        let action = KeyRouter.route(
            kind: kind,
            keyCode: UInt16(event.getIntegerValueField(.keyboardEventKeycode)),
            modifiers: Modifiers(event.flags),
            isActive: isActive
        )

        switch action {
        case .passThrough:
            return Unmanaged.passUnretained(event)
        case .begin:
            isActive = true
        case .commit, .cancel:
            isActive = false
        case .step, .swallow:
            break
        }
        if action != .swallow {
            DispatchQueue.main.async { [onAction] in onAction(action) }
        }
        // Modifier changes always reach apps so nothing thinks ⌘ is stuck down.
        return kind == .flagsChanged ? Unmanaged.passUnretained(event) : nil
    }
}

private func keyTapCallback(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    return Unmanaged<KeyInterceptor>.fromOpaque(refcon).takeUnretainedValue().handle(type: type, event: event)
}
