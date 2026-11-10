/// Which entry of the switcher list is highlighted. Wraps around in both directions.
public struct Selection: Equatable {
    public let count: Int
    public private(set) var index: Int

    /// A forward start lands on the second entry (the previously used window),
    /// a reverse start (⇧⌘Tab) lands on the last one.
    public init(count: Int, reverse: Bool) {
        self.count = count
        if count == 0 {
            index = 0
        } else if reverse {
            index = count - 1
        } else {
            index = count > 1 ? 1 : 0
        }
    }

    public mutating func step(forward: Bool) {
        guard count > 0 else { return }
        index = (index + (forward ? 1 : -1) + count) % count
    }

    /// Jumps to `index`; out-of-range indices are ignored.
    public mutating func select(_ index: Int) {
        guard (0..<count).contains(index) else { return }
        self.index = index
    }
}
