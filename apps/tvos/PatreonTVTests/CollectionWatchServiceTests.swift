//
//  CollectionWatchServiceTests.swift
//  PatreonTVTests
//
//  Bulk collection watch actions select only playable posts, in oldest→newest
//  order, and acknowledge the Continue Collection "new episodes" badge.
//

import XCTest
@testable import PatreonTV

@MainActor
final class CollectionWatchServiceTests: XCTestCase {

    func test_playableIDs_returns_oldest_first_and_skips_unplayable() throws {
        let posts = [
            try post("ep3"),
            try post("text", type: "text_only"),
            try post("ep2"),
            try post("locked", canView: false),
            try post("ep1"),
        ]

        XCTAssertEqual(
            CollectionWatchService.playableIDs(in: posts),
            ["ep1", "ep2", "ep3"]
        )
    }

    func test_playableIDs_deduplicates() throws {
        let posts = [
            try post("ep2"),
            try post("ep2"),
            try post("ep1"),
        ]

        XCTAssertEqual(
            CollectionWatchService.playableIDs(in: posts),
            ["ep1", "ep2"]
        )
    }

    func test_uniqueIDs_includes_every_post_once() throws {
        let posts = [
            try post("ep2"),
            try post("text", type: "text_only"),
            try post("ep1"),
        ]

        XCTAssertEqual(
            CollectionWatchService.uniqueIDs(in: posts),
            ["ep2", "text", "ep1"]
        )
    }

    func test_markedSeen_clears_badge_and_updates_baseline() {
        var entry = RecentCollection(
            id: "c1",
            title: "Season 1",
            squareImageURL: nil,
            wideImageURL: nil,
            numPosts: 12,
            campaignName: nil,
            nextEpisodeTitle: "Episode 1"
        )
        entry.episodeCount = 10
        entry.newEpisodeCount = 3

        let updated = CollectionWatchService.markedSeen(entry, playableCount: 12)

        XCTAssertEqual(updated.episodeCount, 12)
        XCTAssertEqual(updated.newEpisodeCount, 0)
    }

    // MARK: - Helpers

    private func post(
        _ id: String,
        type: String = "video_external_file",
        canView: Bool = true
    ) throws -> Post {
        let json = """
        {
          "type": "post",
          "id": "\(id)",
          "attributes": {
            "title": "\(id)",
            "post_type": "\(type)",
            "current_user_can_view": \(canView)
          }
        }
        """
        return try JSONAPIDecoder.decode(Post.self, from: Data(json.utf8))
    }
}
