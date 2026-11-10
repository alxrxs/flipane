import CoreGraphics
import Foundation
import Testing
@testable import FlipaneCore

@Suite struct WindowFilterTests {
    private func info(id: Int, pid: Int, layer: Int = 0, alpha: Double = 1, w: CGFloat = 800, h: CGFloat = 600) -> [String: Any] {
        [
            kCGWindowNumber as String: NSNumber(value: id),
            kCGWindowOwnerPID as String: NSNumber(value: pid),
            kCGWindowLayer as String: NSNumber(value: layer),
            kCGWindowAlpha as String: NSNumber(value: alpha),
            kCGWindowBounds as String: CGRect(x: 0, y: 0, width: w, height: h).dictionaryRepresentation,
        ]
    }

    @Test func keepsNormalWindowsInOrder() {
        let result = WindowFilter.candidates(from: [info(id: 3, pid: 10), info(id: 1, pid: 11), info(id: 2, pid: 10)], excludingPID: 99)
        #expect(result.map(\.id) == [3, 1, 2])
        #expect(result.first == WindowRecord(id: 3, pid: 10, layer: 0, alpha: 1, bounds: CGRect(x: 0, y: 0, width: 800, height: 600)))
    }

    @Test func dropsNonNormalLayers() {
        #expect(WindowFilter.candidates(from: [info(id: 1, pid: 10, layer: 25)], excludingPID: 99).isEmpty)
    }

    @Test func keepsFloatingLevelWindows() {
        // FaceTime / Phone put their main window on the floating level.
        #expect(WindowFilter.candidates(from: [info(id: 1, pid: 10, layer: 3)], excludingPID: 99).map(\.id) == [1])
    }

    @Test func dropsTransparentWindows() {
        #expect(WindowFilter.candidates(from: [info(id: 1, pid: 10, alpha: 0)], excludingPID: 99).isEmpty)
    }

    @Test func dropsTinyWindows() {
        #expect(WindowFilter.candidates(from: [info(id: 1, pid: 10, w: 20, h: 600), info(id: 2, pid: 10, w: 600, h: 10)], excludingPID: 99).isEmpty)
    }

    @Test func dropsOwnWindows() {
        #expect(WindowFilter.candidates(from: [info(id: 1, pid: 99)], excludingPID: 99).isEmpty)
    }

    @Test func skipsMalformedEntriesAndDefaultsAlpha() {
        var noAlpha = info(id: 5, pid: 10)
        noAlpha.removeValue(forKey: kCGWindowAlpha as String)
        let malformed: [String: Any] = [kCGWindowNumber as String: NSNumber(value: 6)]
        #expect(WindowFilter.candidates(from: [malformed, noAlpha], excludingPID: 99).map(\.id) == [5])
    }
}

@Suite struct SwitchableRoleTests {
    @Test func standardWindowsAlwaysCount() {
        #expect(WindowFilter.isSwitchable(subrole: "AXStandardWindow", hasCloseButton: true))
        #expect(WindowFilter.isSwitchable(subrole: "AXStandardWindow", hasCloseButton: false))
    }

    @Test func dialogsNeedACloseButton() {
        #expect(WindowFilter.isSwitchable(subrole: "AXDialog", hasCloseButton: true))
        // AppKit's floating Siri orb overlay reports as an untitled, buttonless dialog.
        #expect(!WindowFilter.isSwitchable(subrole: "AXDialog", hasCloseButton: false))
    }

    @Test func windowsHidingTheirCloseButtonNeverCount() {
        // Razer Synapse keeps a transparent, buttonless "standard" window open.
        #expect(!WindowFilter.isSwitchable(subrole: "AXStandardWindow", hasCloseButton: true, hidesCloseButton: true))
        #expect(!WindowFilter.isSwitchable(subrole: "AXDialog", hasCloseButton: true, hidesCloseButton: true))
    }

    @Test func otherSubrolesNeverCount() {
        #expect(!WindowFilter.isSwitchable(subrole: "AXFloatingWindow", hasCloseButton: true))
        #expect(!WindowFilter.isSwitchable(subrole: "AXSystemDialog", hasCloseButton: true))
    }
}
