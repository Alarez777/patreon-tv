//
//  CollectionPlaybackResolverTests.swift
//  PatreonTVTests
//
//  Series mode starts a collection at its oldest unfinished episode; with the
//  setting off the resolver keeps resuming the last episode watched.
//

import XCTest
@testable import PatreonTV

@MainActor
final class CollectionPlaybackResolverTests: XCTestCase {

    func test_series_mode_starts_at_oldest_unfinished() throws {
        // `/api/collection` returns post_ids newest-first, hence ep3 → ep1.
        let posts = [try post("ep3"), try post("ep2"), try post("ep1")]

        let target = target(
            posts: posts,
            seriesMode: true,
            progress: ["ep1": progress("ep1", fraction: 1.0)]
        )

        XCTAssertEqual(target?.postID, "ep2")
        XCTAssertEqual(target?.isRestart, false)
    }

    func test_series_mode_resumes_the_oldest_in_progress_episode() throws {
        let posts = [try post("ep3"), try post("ep2"), try post("ep1")]

        let target = target(
            posts: posts,
            seriesMode: true,
            progress: [
                "ep1": progress("ep1", fraction: 1.0),
                "ep2": progress("ep2", fraction: 0.4),
            ]
        )

        XCTAssertEqual(target?.postID, "ep2")
    }

    /// Even when a newer episode is the last one watched, the oldest unfinished
    /// one wins.
    func test_series_mode_ignores_the_most_recently_watched_episode() throws {
        let posts = [try post("ep3"), try post("ep2"), try post("ep1")]
        let watched = progress("ep3", fraction: 0.5)

        let target = target(
            posts: posts,
            seriesMode: true,
            progress: ["ep3": watched],
            recent: watched
        )

        XCTAssertEqual(target?.postID, "ep1")
    }

    func test_series_mode_all_finished_restarts_from_the_oldest() throws {
        let posts = [try post("ep3"), try post("ep2"), try post("ep1")]

        let target = target(
            posts: posts,
            seriesMode: true,
            progress: [
                "ep1": progress("ep1", fraction: 1.0),
                "ep2": progress("ep2", fraction: 0.98),
                "ep3": progress("ep3", fraction: 1.0),
            ]
        )

        XCTAssertEqual(target?.postID, "ep1")
        XCTAssertEqual(target?.isRestart, true)
    }

    func test_series_mode_skips_unplayable_posts() throws {
        let posts = [try post("ep2"), try post("ep1", type: "text_only")]

        let target = target(posts: posts, seriesMode: true)

        XCTAssertEqual(target?.postID, "ep2")
    }

    func test_legacy_mode_resumes_the_last_episode_watched() throws {
        let posts = [try post("ep3"), try post("ep2"), try post("ep1")]
        let watched = progress("ep2", fraction: 0.4)

        let target = target(
            posts: posts,
            seriesMode: false,
            progress: ["ep2": watched],
            recent: watched
        )

        XCTAssertEqual(target?.postID, "ep2")
        XCTAssertEqual(target?.isRestart, false)
    }

    func test_legacy_mode_advances_after_a_finished_episode() throws {
        let posts = [try post("ep3"), try post("ep2"), try post("ep1")]
        let watched = progress("ep2", fraction: 1.0)

        let target = target(
            posts: posts,
            seriesMode: false,
            progress: ["ep2": watched],
            recent: watched
        )

        XCTAssertEqual(target?.postID, "ep3")
    }

    func test_legacy_mode_nothing_watched_starts_at_the_oldest() throws {
        let posts = [try post("ep3"), try post("ep2"), try post("ep1")]

        let target = target(posts: posts, seriesMode: false)

        XCTAssertEqual(target?.postID, "ep1")
    }

    func test_no_playable_posts_returns_nil() throws {
        let posts = [try post("ep1", type: "text_only")]

        XCTAssertNil(target(posts: posts, seriesMode: true))
        XCTAssertNil(target(posts: posts, seriesMode: false))
    }

    // MARK: - Helpers

    private func target(
        posts: [Post],
        seriesMode: Bool,
        progress: [String: PlaybackProgress] = [:],
        recent: PlaybackProgress? = nil
    ) -> CollectionPlaybackResolver.Target? {
        CollectionPlaybackResolver.target(
            in: posts,
            seriesMode: seriesMode,
            progress: { progress[$0] },
            mostRecent: { _ in recent }
        )
    }

    private func progress(_ postID: String, fraction: Double) -> PlaybackProgress {
        PlaybackProgress(
            postID: postID,
            positionSeconds: fraction * 100,
            durationSeconds: 100,
            lastUpdated: Date()
        )
    }

    private func post(
        _ id: String,
        type: String = "video_external_file"
    ) throws -> Post {
        let json = """
        {
          "type": "post",
          "id": "\(id)",
          "attributes": {
            "title": "\(id)",
            "post_type": "\(type)",
            "current_user_can_view": true
          }
        }
        """
        return try JSONAPIDecoder.decode(Post.self, from: Data(json.utf8))
    }
}
