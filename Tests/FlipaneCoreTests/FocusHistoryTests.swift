import CoreGraphics
import FlipaneCore
import Testing

@Suite struct FocusHistoryTests {
    @Test func recentlyFocusedWindowsComeFirst() {
        var history = FocusHistory()
        history.touch(3)
        history.touch(1)
        #expect(history.sorted([1, 2, 3, 4], by: { $0 }) == [1, 3, 2, 4])
    }

    @Test func refocusingMovesAWindowToTheFront() {
        var history = FocusHistory()
        history.touch(1)
        history.touch(2)
        history.touch(1)
        #expect(history.sorted([2, 1], by: { $0 }) == [1, 2])
    }

    @Test func untrackedWindowsKeepTheirOrder() {
        #expect(FocusHistory().sorted([5, 2, 9], by: { $0 }) == [5, 2, 9])
    }

    @Test func historyIsBounded() {
        var history = FocusHistory(limit: 2)
        history.touch(1)
        history.touch(2)
        history.touch(3)
        #expect(history.sorted([1, 2, 3], by: { $0 }) == [3, 2, 1])
    }
}
