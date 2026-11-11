//
//  ContinueCollectionSyncTests.swift
//  PatreonTVTests
//
//  The "N new episodes" rule: only playable episodes count, the badge grows by
//  the delta since the last sync and never exceeds the current episode count.
//

import XCTest
@testable import PatreonTV

final class ContinueCollectionSyncTests: XCTestCase {

    func test_first_sync_seeds_the_baseline_without_a_badge() {
        XCTAssertEqual(
            ContinueCollectionSync.badge(existingCount: nil, existingBadge: nil, newPlayableCount: 12),
            0
        )
    }

    func test_new_episodes_increase_the_badge_by_the_delta() {
        XCTAssertEqual(
            ContinueCollectionSync.badge(existingCount: 10, existingBadge: 0, newPlayableCount: 12),
            2
        )
    }

    func test_unacknowledged_badge_keeps_accumulating() {
        XCTAssertEqual(
            ContinueCollectionSync.badge(existingCount: 10, existingBadge: 3, newPlayableCount: 12),
            5
        )
    }

    func test_removed_episodes_do_not_produce_a_badge() {
        XCTAssertEqual(
            ContinueCollectionSync.badge(existingCount: 10, existingBadge: 0, newPlayableCount: 8),
            0
        )
    }

    func test_badge_never_exceeds_the_current_episode_count() {
        XCTAssertEqual(
            ContinueCollectionSync.badge(existingCount: 10, existingBadge: 5, newPlayableCount: 3),
            3
        )
    }

    func test_empty_collection_has_no_badge() {
        XCTAssertEqual(
            ContinueCollectionSync.badge(existingCount: 10, existingBadge: 4, newPlayableCount: 0),
            0
        )
    }

    func test_membership_maps_post_ids_to_collections() throws {
        let json = """
        {
          "type": "collection",
          "id": "c1",
          "attributes": { "title": "Season 1", "post_ids": [10, 11, 12] }
        }
        """.data(using: .utf8)!
        let collection = try JSONAPIDecoder.decode(PatreonCollection.self, from: json)

        let membership = ContinueCollectionSync.membership(from: [collection])

        XCTAssertEqual(membership["10"], Set(["c1"]))
        XCTAssertEqual(membership["11"], Set(["c1"]))
        XCTAssertEqual(membership["12"], Set(["c1"]))
        XCTAssertNil(membership["13"])
    }
}
