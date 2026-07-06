import XCTest
@testable import LudoDesktop

/// Reconnect backoff policy (CRIE-003 #9): exponential base 0.5s, cap 30s,
/// full jitter. Verifies bounds, monotonic ceiling growth, and the 30s cap.
final class BackoffTests: XCTestCase {
    func testDelayStaysWithinJitterBounds() {
        for attempt in 0..<10 {
            let ceiling = min(LiveAPIClient.backoffBaseNs << UInt64(min(attempt, 6)), LiveAPIClient.backoffCapNs)
            let floor = min(LiveAPIClient.backoffBaseNs / 2, ceiling)
            for _ in 0..<50 {
                let d = LiveAPIClient.backoffDelay(attempt: attempt)
                XCTAssertGreaterThanOrEqual(d, floor)
                XCTAssertLessThanOrEqual(d, ceiling)
            }
        }
    }

    func testCeilingGrowsThenCaps() {
        // Small attempts: ceiling doubles (0.5s, 1s, 2s, …).
        XCTAssertEqual(LiveAPIClient.backoffBaseNs << 0, 500_000_000)
        XCTAssertEqual(LiveAPIClient.backoffBaseNs << 3, 4_000_000_000)
        // Large attempts: never exceed the 30s cap.
        for attempt in 6..<20 {
            XCTAssertLessThanOrEqual(LiveAPIClient.backoffDelay(attempt: attempt), LiveAPIClient.backoffCapNs)
        }
    }
}
