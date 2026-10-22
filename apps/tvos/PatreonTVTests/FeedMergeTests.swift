//
//  FeedMergeTests.swift
//  PatreonTVTests
//
//  Pure merge of a refreshed feed page into the posts already on screen:
//  additions, attribute updates, deduplication, and preservation of pages
//  that fall outside the refreshed window.
//

import XCTest
@testable import PatreonTV

final class FeedMergeTests: XCTestCase {

    /// Decodes a minimal feed. Each tuple is (id, title, publishedAt).
    private func posts(
        _ entries: [(id: String, title: String, publishedAt: String?)]
    ) throws -> [Post] {
        let items = entries.map { entry in
            let published = entry.publishedAt.map { "\"\($0)\"" } ?? "null"
            return """
            {
              "type": "post", "id": "\(entry.id)",
              "attributes": {
                "title": "\(entry.title)",
                "post_type": "video_external_file",
                "published_at": \(published)
              }
            }
            """
        }.joined(separator: ",")
        let json = #"{ "data": [\#(items)] }"#.data(using: .utf8)!
        return try JSONAPIDecoder.decode(MultiResource<Post>.self, from: json).data
    }

    func test_adds_new_posts_newest_first() throws {
        let existing = try posts([
            ("1", "One", "2026-01-01T00:00:00Z"),
            ("2", "Two", "2026-01-02T00:00:00Z"),
        ])
        let incoming = try posts([
            ("3", "Three", "2026-01-03T00:00:00Z"),
            ("2", "Two", "2026-01-02T00:00:00Z"),
        ])

        let outcome = FeedMerge.merge(existing: existing, incoming: incoming)

        XCTAssertEqual(outcome.posts.map(\.id), ["3", "2", "1"])
        XCTAssertEqual(outcome.addedIDs, ["3"])
        XCTAssertTrue(outcome.changed)
    }

    func test_no_changes_is_unchanged() throws {
        let existing = try posts([("1", "One", "2026-01-01T00:00:00Z")])
        let incoming = try posts([("1", "One", "2026-01-01T00:00:00Z")])

        let outcome = FeedMerge.merge(existing: existing, incoming: incoming)

        XCTAssertFalse(outcome.changed)
        XCTAssertTrue(outcome.addedIDs.isEmpty)
        XCTAssertEqual(outcome.posts.map(\.id), ["1"])
    }

    func test_updates_existing_attributes_in_place() throws {
        let existing = try posts([("1", "Old title", "2026-01-01T00:00:00Z")])
        let incoming = try posts([("1", "New title", "2026-01-01T00:00:00Z")])

        let outcome = FeedMerge.merge(existing: existing, incoming: incoming)

        XCTAssertTrue(outcome.changed)
        XCTAssertTrue(outcome.addedIDs.isEmpty)
        XCTAssertEqual(outcome.posts.count, 1)
        XCTAssertEqual(outcome.posts.first?.attributes.title, "New title")
    }

    func test_preserves_posts_missing_from_incoming_page() throws {
        let existing = try posts([
            ("1", "One", "2026-01-02T00:00:00Z"),
            ("2", "Two", "2026-01-01T00:00:00Z"),
        ])
        // Page one only carries the newest post; the older paginated post must
        // survive the merge.
        let incoming = try posts([("1", "One", "2026-01-02T00:00:00Z")])

        let outcome = FeedMerge.merge(existing: existing, incoming: incoming)

        XCTAssertEqual(outcome.posts.map(\.id), ["1", "2"])
        XCTAssertFalse(outcome.changed)
    }

    func test_empty_page_returns_existing_unchanged() throws {
        let existing = try posts([("1", "One", "2026-01-01T00:00:00Z")])

        let outcome = FeedMerge.merge(existing: existing, incoming: [])

        XCTAssertFalse(outcome.changed)
        XCTAssertEqual(outcome.posts.map(\.id), ["1"])
    }
}
