import CoreGraphics

public enum KeyEventKind {
    case keyDown, keyUp, flagsChanged
}

public struct Modifiers: OptionSet, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let command = Modifiers(rawValue: 1 << 0)
    public static let shift = Modifiers(rawValue: 1 << 1)
    public static let option = Modifiers(rawValue: 1 << 2)
    public static let control = Modifiers(rawValue: 1 << 3)

    public init(_ flags: CGEventFlags) {
        var m: Modifiers = []
        if flags.contains(.maskCommand) { m.insert(.command) }
        if flags.contains(.maskShift) { m.insert(.shift) }
        if flags.contains(.maskAlternate) { m.insert(.option) }
        if flags.contains(.maskControl) { m.insert(.control) }
        self = m
    }
}

public enum KeyCode {
    public static let tab: UInt16 = 48
    public static let escape: UInt16 = 53
    public static let returnKey: UInt16 = 36
    public static let leftArrow: UInt16 = 123
    public static let rightArrow: UInt16 = 124
    public static let downArrow: UInt16 = 125
    public static let upArrow: UInt16 = 126
}

public enum KeyAction: Equatable {
    case passThrough
    case swallow
    case begin(reverse: Bool)
    case step(forward: Bool)
    case commit
    case cancel
}

/// Decides what a keyboard event means for the switcher. Pure, so it can be tested
/// without an event tap.
public enum KeyRouter {
    public static func route(kind: KeyEventKind, keyCode: UInt16, modifiers: Modifiers, isActive: Bool) -> KeyAction {
        switch kind {
        case .flagsChanged:
            return isActive && !modifiers.contains(.command) ? .commit : .passThrough

        case .keyUp:
            return isActive ? .swallow : .passThrough

        case .keyDown:
            guard isActive else {
                let isCommandTab = keyCode == KeyCode.tab
                    && modifiers.contains(.command)
                    && !modifiers.contains(.option)
                    && !modifiers.contains(.control)
                return isCommandTab ? .begin(reverse: modifiers.contains(.shift)) : .passThrough
            }
            switch keyCode {
            case KeyCode.tab: return .step(forward: !modifiers.contains(.shift))
            case KeyCode.rightArrow, KeyCode.downArrow: return .step(forward: true)
            case KeyCode.leftArrow, KeyCode.upArrow: return .step(forward: false)
            case KeyCode.escape: return .cancel
            case KeyCode.returnKey: return .commit
            default: return .swallow
            }
        }
    }
}
