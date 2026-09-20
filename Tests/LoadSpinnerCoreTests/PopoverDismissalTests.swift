import XCTest
@testable import LoadSpinnerCore

final class PopoverDismissalTests: XCTestCase {
    func testClickElsewhereInTheAppClosesTheShownPopover() {
        XCTAssertTrue(shouldClosePopover(isShown: true, clickSite: .elsewhere))
    }

    func testClickInsideThePopoverKeepsItOpen() {
        // Every control on both faces lives in the popover's own window.
        XCTAssertFalse(shouldClosePopover(isShown: true, clickSite: .popover))
    }

    func testStatusItemButtonClickIsLeftToTheButtonAction() {
        // Closing here too would make one click close-then-reopen.
        XCTAssertFalse(shouldClosePopover(isShown: true, clickSite: .statusItemButton))
    }

    func testNothingClosesWhileThePopoverIsHidden() {
        for site in [PopoverClickSite.statusItemButton, .popover, .elsewhere] {
            XCTAssertFalse(shouldClosePopover(isShown: false, clickSite: site))
        }
    }
}
