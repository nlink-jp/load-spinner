import XCTest
@testable import LoadSpinnerCore

final class PopoverDismissalTests: XCTestCase {
    func testClickElsewhereInTheAppClosesTheShownPopover() {
        XCTAssertTrue(shouldClosePopover(panelIsUp: true, clickSite: .elsewhere))
    }

    func testClickInsideThePopoverKeepsItOpen() {
        // Every control on both faces lives in the popover's own window.
        XCTAssertFalse(shouldClosePopover(panelIsUp: true, clickSite: .popover))
    }

    func testStatusItemButtonClickIsLeftToTheButtonAction() {
        // Closing here too would make one click close-then-reopen.
        XCTAssertFalse(shouldClosePopover(panelIsUp: true, clickSite: .statusItemButton))
    }

    func testNothingClosesWhileThePopoverIsHidden() {
        for site in [PopoverClickSite.statusItemButton, .popover, .elsewhere] {
            XCTAssertFalse(shouldClosePopover(panelIsUp: false, clickSite: site))
        }
    }
}
