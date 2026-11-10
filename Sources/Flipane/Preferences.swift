import Foundation

/// Which windows the switcher offers, persisted across launches. Both default to off:
/// the cursor's display and the current desktop (Space) only.
enum Preferences {
    private static let defaults = UserDefaults.standard

    static var allDisplays: Bool {
        get { defaults.bool(forKey: "allDisplays") }
        set { defaults.set(newValue, forKey: "allDisplays") }
    }

    static var allDesktops: Bool {
        get { defaults.bool(forKey: "allDesktops") }
        set { defaults.set(newValue, forKey: "allDesktops") }
    }
}
