import XCTest
@testable import HunterCore

final class AudioWorkerTests: XCTestCase {
    func testBlockedHardwareDoesNotBlockCallerAndCancelledWorkCannotContinue() {
        let entered = expectation(description: "hardware preparation entered")
        let completed = expectation(description: "cancelled preparation discarded")
        let release = DispatchSemaphore(value: 0)
        let request = AudioRequest(); let token = request.begin()
        AudioWorker.shared.enqueue {
            entered.fulfill()
            _ = release.wait(timeout: .now() + 3)
            XCTAssertFalse(request.ready(token), "A stopped request must not start late audio")
            completed.fulfill()
        }
        wait(for: [entered], timeout: 2)
        let start = Date()
        request.cancel()
        AudioWorker.shared.enqueue { }
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.2, "Stop and UI submissions must not wait for hardware")
        release.signal(); wait(for: [completed], timeout: 2)
    }
    func testTimeoutCannotCancelAReplacementOrAlreadyPlayingRequest() {
        let request = AudioRequest()
        let old = request.begin(), replacement = request.begin()
        XCTAssertFalse(request.expire(old)); XCTAssertTrue(request.valid(replacement))
        XCTAssertTrue(request.ready(replacement)); XCTAssertFalse(request.expire(replacement))
        let stalled = request.begin()
        XCTAssertTrue(request.expire(stalled)); XCTAssertFalse(request.ready(stalled))
    }
}
