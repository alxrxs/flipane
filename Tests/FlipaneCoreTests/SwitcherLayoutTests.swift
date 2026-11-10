import CoreGraphics
import Testing
@testable import FlipaneCore

/// Expected values are measurements of the system ⌘Tab switcher on a 1920pt-wide display.
@Suite struct SwitcherLayoutTests {
    private func close(_ a: CGFloat, _ b: CGFloat, within tolerance: CGFloat = 1) -> Bool {
        abs(a - b) <= tolerance
    }

    @Test func matchesSystemSwitcherWithSeventeenApps() {
        let layout = SwitcherLayout(itemCount: 17, screenWidth: 1920)
        #expect(close(layout.plate, 92))
        #expect(close(layout.pitch, 106))
        #expect(close(layout.panelSize.width, 1838))
        #expect(close(layout.panelSize.height, 147.5))
        #expect(close(layout.panelCornerRadius, 45))
        #expect(close(layout.plateCornerRadius, 25))
        #expect(close(layout.plateRect(slot: 1).minX, 172 - 41, within: 1.5)) // panel starts 41pt in
        #expect(close(layout.plateRect(slot: 0).minY, 28))
    }

    @Test func matchesSystemSwitcherWithTwentyApps() {
        let layout = SwitcherLayout(itemCount: 20, screenWidth: 1920)
        #expect(close(layout.plate, 78))
        #expect(close(layout.pitch, 90))
        #expect(close(layout.panelSize.height, 131.5))
    }

    @Test func labelBaselineSitsSixteenPointsBelowThePlate() {
        let layout = SwitcherLayout(itemCount: 17, screenWidth: 1920)
        #expect(layout.labelBaseline == layout.plateRect(slot: 0).maxY + 16)
        #expect(layout.labelBaseline < layout.panelSize.height)
    }

    @Test func fewItemsUseTheMaximumSizeAndANarrowPanel() {
        let layout = SwitcherLayout(itemCount: 3, screenWidth: 1920)
        #expect(layout.plate == SwitcherLayout.maximumPlate)
        #expect(layout.visibleCount == 3)
        #expect(layout.panelSize.width < 1920 / 2)
    }

    @Test func manyItemsStopAtTheMinimumSizeAndScroll() {
        let layout = SwitcherLayout(itemCount: 200, screenWidth: 1920)
        #expect(layout.plate == SwitcherLayout.minimumPlate)
        #expect(layout.visibleCount < 200)
        #expect(layout.panelSize.width <= 1920 - 2 * SwitcherLayout.screenMargin)
    }

    @Test func iconIsLargerThanThePlateAndConcentric() {
        let layout = SwitcherLayout(itemCount: 17, screenWidth: 1920)
        let plate = layout.plateRect(slot: 4), icon = layout.iconRect(slot: 4)
        #expect(close(icon.width, plate.width * 1.094, within: 0.01))
        #expect(close(icon.midX, plate.midX, within: 0.01) && close(icon.midY, plate.midY, within: 0.01))
    }

    @Test func scrollingKeepsTheSelectionVisible() {
        let layout = SwitcherLayout(itemCount: 200, screenWidth: 1920)
        let n = layout.visibleCount
        #expect(layout.firstVisible(keeping: 0, from: 0) == 0)
        #expect(layout.firstVisible(keeping: n - 1, from: 0) == 0)
        #expect(layout.firstVisible(keeping: n, from: 0) == 1)
        #expect(layout.firstVisible(keeping: 199, from: 0) == 200 - n)
        #expect(layout.firstVisible(keeping: 5, from: 50) == 5)
    }

    @Test func minimumWidthWidensThePanelAndCentresTheRow() {
        let narrow = SwitcherLayout(itemCount: 2, screenWidth: 1920)
        let wide = SwitcherLayout(itemCount: 2, screenWidth: 1920, minimumWidth: 700)
        #expect(wide.panelSize.width == 700)
        #expect(wide.plate == narrow.plate)
        let rowMid = (wide.plateRect(slot: 0).minX + wide.plateRect(slot: 1).maxX) / 2
        #expect(close(rowMid, 350, within: 0.01))
    }

    @Test func minimumWidthNeverExceedsTheScreenLimit() {
        let layout = SwitcherLayout(itemCount: 2, screenWidth: 1000, minimumWidth: 5000)
        #expect(layout.panelSize.width == 1000 - 2 * SwitcherLayout.screenMargin)
    }
}

@Suite struct SwitcherLayoutHitTests {
    @Test func findsTheSlotUnderThePointer() {
        let layout = SwitcherLayout(itemCount: 3, screenWidth: 1920)
        for slot in 0..<3 {
            let plate = layout.plateRect(slot: slot)
            #expect(layout.slot(at: CGPoint(x: plate.midX, y: plate.midY)) == slot)
        }
    }

    @Test func gapsBetweenPlatesBelongToASlot() {
        let layout = SwitcherLayout(itemCount: 3, screenWidth: 1920)
        let gap = (layout.plateRect(slot: 0).maxX + layout.plateRect(slot: 1).minX) / 2
        #expect(layout.slot(at: CGPoint(x: gap - 0.5, y: 10)) == 0)
        #expect(layout.slot(at: CGPoint(x: gap + 0.5, y: 10)) == 1)
    }

    @Test func outsideTheRowIsNoSlot() {
        let layout = SwitcherLayout(itemCount: 3, screenWidth: 1920, minimumWidth: 1000)
        #expect(layout.slot(at: CGPoint(x: 1, y: 10)) == nil)
        #expect(layout.slot(at: CGPoint(x: layout.panelSize.width - 1, y: 10)) == nil)
        #expect(layout.slot(at: CGPoint(x: layout.plateRect(slot: 1).midX, y: -1)) == nil)
    }
}
