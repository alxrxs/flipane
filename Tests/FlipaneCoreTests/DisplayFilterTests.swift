import CoreGraphics
import Testing
@testable import FlipaneCore

@Suite struct DisplayFilterTests {
    // Two side-by-side displays in global (top-left origin) coordinates.
    private let left = CGRect(x: 0, y: 0, width: 1000, height: 800)
    private let right = CGRect(x: 1000, y: 0, width: 1200, height: 900)

    private func window(_ id: CGWindowID, _ rect: CGRect) -> WindowRecord {
        WindowRecord(id: id, pid: 1, layer: 0, alpha: 1, bounds: rect)
    }

    @Test func keepsOnlyWindowsOnCursorDisplayInOrder() {
        let windows = [
            window(1, CGRect(x: 1100, y: 100, width: 400, height: 300)),
            window(2, CGRect(x: 100, y: 100, width: 400, height: 300)),
            window(3, CGRect(x: 1500, y: 200, width: 400, height: 300)),
        ]
        let result = WindowFilter.onDisplay(windows, displays: [left, right], cursor: CGPoint(x: 1600, y: 400))
        #expect(result.map(\.id) == [1, 3])
    }

    @Test func spanningWindowBelongsToDisplayWithMostOfIt() {
        let mostlyRight = window(1, CGRect(x: 900, y: 100, width: 600, height: 300))
        let mostlyLeft = window(2, CGRect(x: 500, y: 100, width: 600, height: 300))
        #expect(WindowFilter.onDisplay([mostlyRight, mostlyLeft], displays: [left, right], cursor: CGPoint(x: 1200, y: 10)).map(\.id) == [1])
        #expect(WindowFilter.onDisplay([mostlyRight, mostlyLeft], displays: [left, right], cursor: CGPoint(x: 10, y: 10)).map(\.id) == [2])
    }

    @Test func cursorOutsideEveryDisplayKeepsAllWindows() {
        let windows = [window(1, CGRect(x: 100, y: 100, width: 400, height: 300))]
        #expect(WindowFilter.onDisplay(windows, displays: [left, right], cursor: CGPoint(x: -50, y: -50)).map(\.id) == [1])
    }

    @Test func windowOffAllDisplaysIsDropped() {
        let offscreen = window(1, CGRect(x: 5000, y: 5000, width: 400, height: 300))
        #expect(WindowFilter.onDisplay([offscreen], displays: [left, right], cursor: CGPoint(x: 10, y: 10)).isEmpty)
    }
}
