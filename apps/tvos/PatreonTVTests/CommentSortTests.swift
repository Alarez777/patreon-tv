//
//  CommentSortTests.swift
//  PatreonTVTests
//
//  Sort labels and the query values the comments endpoint expects.
//

import XCTest
@testable import PatreonTV

final class CommentSortTests: XCTestCase {

    func test_apiValue_maps_each_sort() {
        XCTAssertEqual(CommentSort.best.apiValue, "-vote_sum")
        XCTAssertEqual(CommentSort.newest.apiValue, "-created")
        XCTAssertEqual(CommentSort.oldest.apiValue, "created")
    }

    func test_titles() {
        XCTAssertEqual(CommentSort.best.title, "Best")
        XCTAssertEqual(CommentSort.newest.title, "Newest")
        XCTAssertEqual(CommentSort.oldest.title, "Oldest")
    }
}
