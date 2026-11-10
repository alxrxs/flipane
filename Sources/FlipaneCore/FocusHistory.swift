import CoreGraphics

/// Windows in the order they were last focused, most recent first. The window server's list is
/// only front-to-back within the current Space, so recency across Spaces has to be tracked.
public struct FocusHistory {
    private var recent: [CGWindowID] = []
    private let limit: Int

    public init(limit: Int = 500) {
        self.limit = limit
    }

    public mutating func touch(_ id: CGWindowID) {
        if recent.first == id { return }
        recent.removeAll { $0 == id }
        recent.insert(id, at: 0)
        if recent.count > limit { recent.removeLast(recent.count - limit) }
    }

    /// Windows focused since tracking began come first, most recent first; the rest keep their
    /// given order after them.
    public func sorted<T>(_ items: [T], by id: (T) -> CGWindowID) -> [T] {
        let rank = Dictionary(recent.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return items.enumerated().sorted { a, b in
            switch (rank[id(a.element)], rank[id(b.element)]) {
            case let (x?, y?): x < y
            case (_?, nil): true
            case (nil, _?): false
            case (nil, nil): a.offset < b.offset
            }
        }.map(\.element)
    }
}
