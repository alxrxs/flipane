import CoreGraphics

/// Geometry of the side-by-side switcher, measured from the system ⌘Tab switcher on macOS 27
/// (2x captures at 17–20 apps on a 1920pt-wide display). Everything scales with the selection
/// plate's side; the plate shrinks so the row fits the screen, as the system switcher does.
/// Coordinates are top-left origin, relative to the panel.
public struct SwitcherLayout: Equatable {
    /// The system switcher was width-limited in every capture, so its cap wasn't observed.
    public static let maximumPlate: CGFloat = 108
    /// Below this, items stop shrinking and the row scrolls instead.
    public static let minimumPlate: CGFloat = 28
    /// Item pitch over plate side (gap between plates ≈ 15% of the plate).
    public static let pitchRatio: CGFloat = 1.15
    /// Panel edge to the first and last item slot.
    public static let sidePadding: CGFloat = 18.5
    /// Minimum distance from the panel to the screen's left and right edges.
    public static let screenMargin: CGFloat = 41
    /// App icons are drawn larger than the plate: their transparent margin overlaps it, leaving
    /// the visible icon shape at 0.88 of the plate.
    public static let iconRatio: CGFloat = 1.094
    public static let plateCornerRatio: CGFloat = 0.27
    public static let panelCornerRatio: CGFloat = 0.305
    /// Label baseline below the plate's bottom edge.
    public static let labelBaselineOffset: CGFloat = 16

    public let itemCount: Int
    /// How many items fit; fewer than `itemCount` only when items are at `minimumPlate`.
    public let visibleCount: Int
    public let plate: CGFloat
    public let pitch: CGFloat
    public let verticalPadding: CGFloat
    public let panelSize: CGSize
    /// Left edge of the first item slot; more than `sidePadding` when the panel was widened.
    public let rowInset: CGFloat

    /// `minimumWidth` widens the panel (up to the screen limit) beyond the icon row, which then
    /// stays centred. Window titles are longer than app names and need the room.
    public init(itemCount: Int, screenWidth: CGFloat, minimumWidth: CGFloat = 0) {
        let count = max(1, itemCount)
        let available = screenWidth - 2 * Self.screenMargin - 2 * Self.sidePadding
        let fitted = available / (CGFloat(count) * Self.pitchRatio)
        let plate = min(Self.maximumPlate, max(Self.minimumPlate, fitted))
        let pitch = plate * Self.pitchRatio
        let visible = min(count, max(1, Int(available / pitch)))
        let verticalPadding = 21 + 0.075 * plate
        let rowWidth = CGFloat(visible) * pitch + 2 * Self.sidePadding
        let width = max(rowWidth, min(minimumWidth, screenWidth - 2 * Self.screenMargin))

        self.itemCount = itemCount
        self.visibleCount = visible
        self.plate = plate
        self.pitch = pitch
        self.verticalPadding = verticalPadding
        self.panelSize = CGSize(width: width, height: plate + 2 * verticalPadding)
        self.rowInset = Self.sidePadding + (width - rowWidth) / 2
    }

    public var panelCornerRadius: CGFloat { panelSize.height * Self.panelCornerRatio }
    public var plateCornerRadius: CGFloat { plate * Self.plateCornerRatio }
    public var labelBaseline: CGFloat { verticalPadding + plate + Self.labelBaselineOffset }

    /// The plate of the item in visible slot `slot` (0 = leftmost visible).
    public func plateRect(slot: Int) -> CGRect {
        CGRect(
            x: rowInset + CGFloat(slot) * pitch + (pitch - plate) / 2,
            y: verticalPadding,
            width: plate,
            height: plate
        )
    }

    public func iconRect(slot: Int) -> CGRect {
        let plateRect = plateRect(slot: slot)
        let inset = plate * (1 - Self.iconRatio) / 2
        return plateRect.insetBy(dx: inset, dy: inset)
    }

    /// The visible slot under `point` (panel coordinates), or nil between the row's ends.
    /// Each slot owns its full pitch and the panel's full height, so gaps between plates
    /// still count and the pointer never falls through.
    public func slot(at point: CGPoint) -> Int? {
        guard point.y >= 0, point.y <= panelSize.height else { return nil }
        let offset = point.x - rowInset
        guard offset >= 0 else { return nil }
        let slot = Int(offset / pitch)
        return slot < visibleCount ? slot : nil
    }

    /// First visible item so that `selected` is on screen, moving as little as possible from `current`.
    public func firstVisible(keeping selected: Int, from current: Int) -> Int {
        let maxFirst = max(0, itemCount - visibleCount)
        let first = min(max(current, selected - visibleCount + 1), selected)
        return min(max(0, first), maxFirst)
    }
}
