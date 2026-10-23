//
//  CommentSortTests.swift
//  PatreonTVTests
//
//  Query values the comments endpoint expects.
//

import XCTest
@testable import PatreonTV

final class CommentSortTests: XCTestCase {

    func test_apiValue_maps_each_sort() {
        XCTAssertEqual(CommentSort.best.apiValue, "-vote_sum")
        XCTAssertEqual(CommentSort.newest.apiValue, "-created")
        XCTAssertEqual(CommentSort.oldest.apiValue, "created")
    }
}
