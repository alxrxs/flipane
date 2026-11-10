import Testing
@testable import FlipaneCore

@Suite struct SelectionTests {
    @Test func forwardStartPicksPreviousWindow() {
        #expect(Selection(count: 3, reverse: false).index == 1)
    }

    @Test func forwardStartWithSingleWindowPicksIt() {
        #expect(Selection(count: 1, reverse: false).index == 0)
    }

    @Test func reverseStartPicksLastWindow() {
        #expect(Selection(count: 4, reverse: true).index == 3)
    }

    @Test func stepsWrapInBothDirections() {
        var s = Selection(count: 3, reverse: false)
        s.step(forward: true)
        #expect(s.index == 2)
        s.step(forward: true)
        #expect(s.index == 0)
        s.step(forward: false)
        #expect(s.index == 2)
    }

    @Test func emptySelectionIgnoresSteps() {
        var s = Selection(count: 0, reverse: false)
        s.step(forward: true)
        s.step(forward: false)
        #expect(s.index == 0)
    }
}

@Suite struct SelectionJumpTests {
    @Test func selectJumpsToAnEntry() {
        var selection = Selection(count: 4, reverse: false)
        selection.select(3)
        #expect(selection.index == 3)
    }

    @Test func selectIgnoresOutOfRange() {
        var selection = Selection(count: 4, reverse: false)
        selection.select(4)
        selection.select(-1)
        #expect(selection.index == 1)
    }
}
