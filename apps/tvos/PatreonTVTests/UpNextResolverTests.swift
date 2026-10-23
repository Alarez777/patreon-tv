//
//  UpNextResolverTests.swift
//  PatreonTVTests
//
//  Selection logic for the Up Next queue: playability filtering, unwatched
//  preference, "everything watched" fallback, and the ordered candidates a
//  shelf hands to the detail view.
//

import XCTest
@testable import PatreonTV

final class UpNextResolverTests: XCTestCase {

    /// Decodes a minimal campaign feed. Each tuple is (id, post_type, canView).
    private func posts(_ entries: [(id: String, type: String, canView: Bool)]) throws -> [Post] {
        let items = entries.map { entry in
            """
            {
              "type": "post", "id": "\(entry.id)",
              "attributes": {
                "title": "Post \(entry.id)",
                "post_type": "\(entry.type)",
                "current_user_can_view": \(entry.canView)
              }
            }
            """
        }.joined(separator: ",")
        let json = #"{ "data": [\#(items)] }"#.data(using: .utf8)!
        return try JSONAPIDecoder.decode(MultiResource<Post>.self, from: json).data
    }

    func test_picks_immediate_next_playable() throws {
        let feed = try posts([
            ("1", "video_external_file", true),
            ("2", "video_external_file", true),
            ("3", "video_external_file", true),
        ])
        let next = UpNextResolver.selectNext(afterPostID: "1", in: feed) { _ in false }
        XCTAssertEqual(next?.id, "2")
    }

    func test_skips_non_playable_types() throws {
        let feed = try posts([
            ("1", "video_external_file", true),
            ("2", "text_only", true),
            ("3", "image_file", true),
            ("4", "podcast", true),
        ])
        let next = UpNextResolver.selectNext(afterPostID: "1", in: feed) { _ in false }
        XCTAssertEqual(next?.id, "4")
    }

    func test_skips_locked_posts() throws {
        let feed = try posts([
            ("1", "video_external_file", true),
            ("2", "video_external_file", false),
            ("3", "video_external_file", true),
        ])
        let next = UpNextResolver.selectNext(afterPostID: "1", in: feed) { _ in false }
        XCTAssertEqual(next?.id, "3")
    }

    func test_prefers_unwatched_over_watched() throws {
        let feed = try posts([
            ("1", "video_external_file", true),
            ("2", "video_external_file", true),
            ("3", "video_external_file", true),
        ])
        let next = UpNextResolver.selectNext(afterPostID: "1", in: feed) { $0 == "2" }
        XCTAssertEqual(next?.id, "3")
    }

    func test_falls_back_to_watched_when_everything_finished() throws {
        let feed = try posts([
            ("1", "video_external_file", true),
            ("2", "video_external_file", true),
            ("3", "video_external_file", true),
        ])
        let next = UpNextResolver.selectNext(afterPostID: "1", in: feed) { _ in true }
        XCTAssertEqual(next?.id, "2")
    }

    func test_nil_when_current_post_is_last() throws {
        let feed = try posts([
            ("1", "video_external_file", true),
            ("2", "video_external_file", true),
        ])
        XCTAssertNil(UpNextResolver.selectNext(afterPostID: "2", in: feed) { _ in false })
    }

    func test_nil_when_current_post_not_in_feed() throws {
        let feed = try posts([("1", "video_external_file", true)])
        XCTAssertNil(UpNextResolver.selectNext(afterPostID: "99", in: feed) { _ in false })
    }

    func test_audio_types_are_playable() throws {
        let feed = try posts([
            ("1", "podcast", true),
            ("2", "audio_file", true),
        ])
        let next = UpNextResolver.selectNext(afterPostID: "1", in: feed) { _ in false }
        XCTAssertEqual(next?.id, "2")
    }

    // MARK: - Shelf queue ("New")

    func test_shelf_candidates_are_ordered_to_the_right() {
        let queue = ["1", "2", "3"]
        XCTAssertEqual(
            UpNextResolver.candidatesAfter("1", in: queue) { _ in false },
            ["2", "3"]
        )
    }

    func test_shelf_candidates_skip_finished() {
        let queue = ["1", "2", "3"]
        XCTAssertEqual(
            UpNextResolver.candidatesAfter("1", in: queue) { $0 == "2" },
            ["3"]
        )
    }

    func test_shelf_candidates_empty_at_end_of_shelf() {
        XCTAssertEqual(
            UpNextResolver.candidatesAfter("2", in: ["1", "2"]) { _ in false },
            []
        )
    }

    func test_shelf_candidates_empty_when_all_remaining_finished() {
        let queue = ["1", "2", "3"]
        XCTAssertEqual(
            UpNextResolver.candidatesAfter("1", in: queue) { $0 != "1" },
            []
        )
    }

    func test_shelf_candidates_empty_when_current_not_in_queue() {
        XCTAssertEqual(
            UpNextResolver.candidatesAfter("9", in: ["1", "2"]) { _ in false },
            []
        )
    }

    func test_shelf_candidates_respect_limit() {
        let queue = (0..<20).map(String.init)
        XCTAssertEqual(
            UpNextResolver.candidatesAfter("0", in: queue, isFinished: { _ in false }, limit: 5),
            ["1", "2", "3", "4", "5"]
        )
    }
}
