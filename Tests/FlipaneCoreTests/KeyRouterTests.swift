import Testing
@testable import FlipaneCore

@Suite struct KeyRouterTests {
    private func route(_ kind: KeyEventKind, _ key: UInt16 = 0, _ mods: Modifiers = [], active: Bool) -> KeyAction {
        KeyRouter.route(kind: kind, keyCode: key, modifiers: mods, isActive: active)
    }

    @Test func commandTabBeginsForward() {
        #expect(route(.keyDown, KeyCode.tab, [.command], active: false) == .begin(reverse: false))
    }

    @Test func commandShiftTabBeginsReverse() {
        #expect(route(.keyDown, KeyCode.tab, [.command, .shift], active: false) == .begin(reverse: true))
    }

    @Test func otherTabCombosPassThroughWhenInactive() {
        #expect(route(.keyDown, KeyCode.tab, [], active: false) == .passThrough)
        #expect(route(.keyDown, KeyCode.tab, [.command, .option], active: false) == .passThrough)
        #expect(route(.keyDown, KeyCode.tab, [.command, .control], active: false) == .passThrough)
        #expect(route(.keyDown, 12, [.command], active: false) == .passThrough)
        #expect(route(.keyUp, KeyCode.tab, [.command], active: false) == .passThrough)
        #expect(route(.flagsChanged, active: false) == .passThrough)
    }

    @Test func navigationWhileActive() {
        #expect(route(.keyDown, KeyCode.tab, [.command], active: true) == .step(forward: true))
        #expect(route(.keyDown, KeyCode.tab, [.command, .shift], active: true) == .step(forward: false))
        #expect(route(.keyDown, KeyCode.rightArrow, [.command], active: true) == .step(forward: true))
        #expect(route(.keyDown, KeyCode.downArrow, [.command], active: true) == .step(forward: true))
        #expect(route(.keyDown, KeyCode.leftArrow, [.command], active: true) == .step(forward: false))
        #expect(route(.keyDown, KeyCode.upArrow, [.command], active: true) == .step(forward: false))
    }

    @Test func escapeCancelsAndReturnCommits() {
        #expect(route(.keyDown, KeyCode.escape, [.command], active: true) == .cancel)
        #expect(route(.keyDown, KeyCode.returnKey, [.command], active: true) == .commit)
    }

    @Test func releasingCommandCommits() {
        #expect(route(.flagsChanged, 55, [], active: true) == .commit)
        #expect(route(.flagsChanged, 56, [.command], active: true) == .passThrough)
        #expect(route(.flagsChanged, 56, [.shift], active: true) == .commit)
    }

    @Test func otherKeysAreSwallowedWhileActive() {
        #expect(route(.keyDown, 12, [.command], active: true) == .swallow)
        #expect(route(.keyUp, KeyCode.tab, [.command], active: true) == .swallow)
    }

    @Test func modifiersFromEventFlags() {
        #expect(Modifiers([.maskCommand, .maskShift]) == [.command, .shift])
        #expect(Modifiers([.maskAlternate, .maskControl]) == [.option, .control])
        #expect(Modifiers([]) == [])
    }
}
