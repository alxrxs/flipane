import AppKit
import FlipaneCore
import QuartzCore

/// The on-screen switcher: a row of app icons on one Liquid Glass panel, laid out like the
/// system ⌘Tab switcher (see `SwitcherLayout`), with the selected window's title underneath.
/// Created once and reused; icons are pooled and nothing animates implicitly, so each keystroke
/// is a handful of layer property changes.
final class SwitcherPanel {
    /// Longer labels are truncated rather than stretching the panel further.
    private static let maximumLabelWidth: CGFloat = 280

    private let panel: NSPanel
    private let glass = NSGlassEffectView()
    private let root = PointerView()
    private let plate = PlateView()
    private let label = LabelView()
    private var icons: [NSImageView] = []
    private var windows: [SwitchableWindow] = []
    private var labels: [String] = []
    private var layout = SwitcherLayout(itemCount: 1, screenWidth: 1)
    private var firstVisible = 0
    private var selectedIndex = -1

    var isVisible: Bool { panel.isVisible }
    /// The pointer moved onto the item at this index.
    var onHover: ((Int) -> Void)?
    /// The item at this index was clicked.
    var onClick: ((Int) -> Void)?

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 150),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]

        // System glass: follows the Liquid Glass transparency setting, Reduce Transparency
        // and Increase Contrast without any work on our side.
        glass.style = .regular
        glass.contentView = root
        panel.contentView = glass
        // The system switcher is dark in light mode too (white label, black plate); left alone,
        // the glass would also flip its content to light over bright wallpaper.
        panel.appearance = NSAppearance(named: .darkAqua)

        root.wantsLayer = true
        root.onMove = { [weak self] point in
            guard let self, let index = self.index(at: point), index != self.selectedIndex else { return }
            self.onHover?(index)
        }
        root.onClick = { [weak self] point in
            guard let self, let index = self.index(at: point) else { return }
            self.onClick?(index)
        }
        root.addSubview(plate)
        root.addSubview(label)

        prewarm()
    }

    func show(_ windows: [SwitchableWindow], selected: Int) {
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
            ?? NSScreen.main ?? NSScreen.screens[0]
        self.windows = windows
        // The app name, as the system switcher shows; the window title only tells apart
        // several windows of the same app.
        let windowsPerApp = Dictionary(windows.map { ($0.pid, 1) }, uniquingKeysWith: +)
        labels = windows.map { windowsPerApp[$0.pid, default: 0] > 1 ? $0.title : $0.appName }
        let longestTitle = labels.lazy.map { self.label.width(of: $0) }.max() ?? 0
        layout = SwitcherLayout(
            itemCount: windows.count,
            screenWidth: screen.frame.width,
            minimumWidth: min(longestTitle, Self.maximumLabelWidth) + 2 * SwitcherLayout.sidePadding
        )
        // Centred on the whole screen, menu bar and Dock included, like the system switcher.
        let size = layout.panelSize
        let frame = NSRect(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.midY - size.height / 2,
            width: size.width,
            height: size.height
        ).integral

        withoutAnimation {
            panel.setFrame(frame, display: false)
            glass.cornerRadius = layout.panelCornerRadius
            while icons.count < layout.visibleCount {
                let icon = NSImageView()
                icon.imageScaling = .scaleProportionallyUpOrDown
                icons.append(icon)
                root.addSubview(icon, positioned: .above, relativeTo: plate)
            }
            for (slot, icon) in icons.enumerated() {
                icon.isHidden = slot >= layout.visibleCount
                if !icon.isHidden { icon.frame = layout.iconRect(slot: slot) }
            }
            plate.layer?.cornerRadius = layout.plateCornerRadius
            label.refresh()
            firstVisible = 0
            selectedIndex = -1
            fillIcons()
            select(selected)
        }
        panel.orderFrontRegardless()
    }

    func select(_ index: Int) {
        guard windows.indices.contains(index) else { return }
        withoutAnimation {
            let first = layout.firstVisible(keeping: index, from: firstVisible)
            if first != firstVisible {
                firstVisible = first
                fillIcons()
            }
            selectedIndex = index
            let plateRect = layout.plateRect(slot: index - firstVisible)
            plate.frame = plateRect

            label.text = labels[index]
            let inner = root.bounds.insetBy(dx: SwitcherLayout.sidePadding, dy: 0)
            let width = min(label.fittingWidth, inner.width, Self.maximumLabelWidth)
            let x = min(max(plateRect.midX - width / 2, inner.minX), inner.maxX - width)
            label.frame = label.frame(x: x, width: width, baseline: layout.labelBaseline)
        }
    }

    func hide() {
        panel.orderOut(nil)
        windows = []
        labels = []
        for icon in icons { icon.image = nil }
    }

    private func index(at point: CGPoint) -> Int? {
        guard let slot = layout.slot(at: point) else { return nil }
        let index = firstVisible + slot
        return windows.indices.contains(index) ? index : nil
    }

    private func fillIcons() {
        for slot in 0..<layout.visibleCount {
            let index = firstVisible + slot
            icons[slot].image = windows.indices.contains(index) ? windows[index].icon : nil
        }
    }

    /// Forces the window server and Core Animation to build the glass backing once at launch,
    /// so the first ⌘Tab doesn't pay for it.
    private func prewarm() {
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.displayIfNeeded()
        panel.orderOut(nil)
        panel.alphaValue = 1
    }

    private func withoutAnimation(_ body: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        body()
        CATransaction.commit()
    }
}

class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

/// Takes every pointer event over the panel, icons included, and reports where it happened.
/// The panel never becomes key, so clicks are accepted as first mouse and hover is tracked
/// whatever app is active.
private final class PointerView: FlippedView {
    var onMove: ((CGPoint) -> Void)?
    var onClick: ((CGPoint) -> Void)?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self))
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        super.hitTest(point) == nil ? nil : self
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseMoved(with event: NSEvent) { onMove?(location(of: event)) }
    override func mouseDragged(with event: NSEvent) { onMove?(location(of: event)) }
    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) { onClick?(location(of: event)) }

    private func location(of event: NSEvent) -> CGPoint {
        convert(event.locationInWindow, from: nil)
    }
}

/// The selection: a rounded plate behind the selected icon. Near-black in dark mode, as the
/// system switcher draws it.
private final class PlateView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerCurve = .continuous
        layer?.actions = ["position": NSNull(), "bounds": NSNull(), "backgroundColor": NSNull(), "cornerRadius": NSNull()]
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshColor()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        refreshColor()
    }

    private func refreshColor() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        layer?.backgroundColor = NSColor.black.withAlphaComponent(isDark ? 0.9 : 0.15).cgColor
    }
}

/// The selected window's title: 13pt bold, one line, truncated, positioned by its baseline.
private final class LabelView: NSView {
    private static let font = NSFont.systemFont(ofSize: 13, weight: .bold)
    private var attributes: [NSAttributedString.Key: Any] = [:]

    var text = "" {
        didSet { needsDisplay = true }
    }

    var fittingWidth: CGFloat { width(of: text) }

    func width(of string: String) -> CGFloat {
        ceil((string as NSString).size(withAttributes: attributes).width)
    }

    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        refresh()
    }

    required init?(coder: NSCoder) { fatalError() }

    func refresh() {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        style.alignment = .center
        attributes = [.font: Self.font, .foregroundColor: NSColor.labelColor, .paragraphStyle: style]
        needsDisplay = true
    }

    /// A frame whose text baseline lands on `baseline` (in the superview's flipped space).
    func frame(x: CGFloat, width: CGFloat, baseline: CGFloat) -> NSRect {
        let font = Self.font
        return NSRect(x: x, y: baseline - font.ascender, width: width, height: ceil(font.ascender - font.descender))
    }

    override func draw(_ dirtyRect: NSRect) {
        (text as NSString).draw(with: bounds, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: attributes)
    }
}
