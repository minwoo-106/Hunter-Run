import XCTest
@testable import HunterCore

final class PresentationClockTests: XCTestCase {
    func testCancelledHomeGestureRetainsFrameAndCannotHandoffWhileInactive() {
        var clock = PresentationClock(duration: 2.55, handoff: 0.70, at: 100)
        clock.advance(to: 100.4)
        clock.setActive(false, at: 100.5)
        clock.advance(to: 160)
        XCTAssertEqual(clock.elapsed, 0.5, accuracy: 0.001)
        XCTAssertFalse(clock.handedOff); XCTAssertFalse(clock.complete)
        clock.setActive(true, at: 160)
        clock.advance(to: 160.5)
        XCTAssertEqual(clock.elapsed, 1, accuracy: 0.001)
        XCTAssertFalse(clock.handedOff)
        clock.advance(to: 161.3)
        XCTAssertTrue(clock.handedOff); XCTAssertFalse(clock.complete)
        clock.advance(to: 163)
        XCTAssertTrue(clock.complete)
    }
    func testRepeatedInactiveBackgroundNotificationsDoNotCreditSuspendedTime() {
        var clock = PresentationClock(duration: 2.1, handoff: 0.60, at: 1)
        clock.setActive(false, at: 1.3)
        clock.setActive(false, at: 40)
        clock.setActive(true, at: 100)
        clock.setActive(true, at: 100)
        clock.advance(to: 100.2)
        XCTAssertEqual(clock.elapsed, 0.5, accuracy: 0.001)
        XCTAssertFalse(clock.handedOff)
    }
    func testPauseAfterHandoffKeepsDestinationButDoesNotFinishCover() {
        var clock = PresentationClock(duration: 3.7, handoff: 0.78, at: 0)
        clock.advance(to: 3)
        clock.setActive(false, at: 3.1)
        XCTAssertTrue(clock.handedOff); XCTAssertFalse(clock.complete)
        clock.setActive(true, at: 100)
        clock.advance(to: 100.6)
        XCTAssertTrue(clock.complete)
    }
}
