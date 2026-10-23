//
//  AppCacheTests.swift
//  PatreonTVTests
//
//  Smoke coverage for cache accounting: clearing must not throw and must
//  report a sane byte count.
//

import XCTest
@testable import PatreonTV

@MainActor
final class AppCacheTests: XCTestCase {

    func test_size_and_clear_report_non_negative_bytes() async {
        let before = await AppCache.size()
        let freed = await AppCache.clear()
        let after = await AppCache.size()

        XCTAssertGreaterThanOrEqual(before, 0)
        XCTAssertGreaterThanOrEqual(freed, 0)
        XCTAssertGreaterThanOrEqual(after, 0)
    }
}
