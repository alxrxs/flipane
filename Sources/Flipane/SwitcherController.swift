import FlipaneCore
import Foundation

/// Turns key actions into switcher behaviour. Main thread only.
final class SwitcherController {
    private let panel = SwitcherPanel()
    private var windows: [SwitchableWindow] = []
    private var selection = Selection(count: 0, reverse: false)
    /// Called when the switcher closes on its own (a click), so the key tap stops
    /// treating keystrokes as switcher input.
    var onDismiss: (() -> Void)?

    init() {
        panel.onHover = { [weak self] index in self?.select(index) }
        panel.onClick = { [weak self] index in
            guard let self else { return }
            select(index)
            commit()
            onDismiss?()
        }
    }

    func handle(_ action: KeyAction) {
        switch action {
        case .begin(let reverse):
            windows = WindowList.current()
            selection = Selection(count: windows.count, reverse: reverse)
            guard !windows.isEmpty else { return }
            panel.show(windows, selected: selection.index)

        case .step(let forward):
            guard !windows.isEmpty else { return }
            selection.step(forward: forward)
            panel.select(selection.index)

        case .commit:
            commit()

        case .cancel:
            panel.hide()
            windows = []

        case .passThrough, .swallow:
            break
        }
    }

    private func select(_ index: Int) {
        guard panel.isVisible else { return }
        selection.select(index)
        panel.select(selection.index)
    }

    private func commit() {
        let target = windows.indices.contains(selection.index) ? windows[selection.index] : nil
        panel.hide()
        windows = []
        if let target {
            FocusTracker.shared.touch(target.id)
            WindowActivator.focus(target)
        }
    }
}
