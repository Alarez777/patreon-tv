//
//  CollectionSelectionStateTests.swift
//  PatreonTVTests
//
//  Selection mode only includes playable posts and always starts from the post
//  that opened the menu.
//

import XCTest
@testable import PatreonTV

final class CollectionSelectionStateTests: XCTestCase {

    func test_begin_selects_anchor_and_activates_mode() throws {
        var state = CollectionSelectionState()

        state.begin(with: try post("ep1"))

        XCTAssertTrue(state.isActive)
        XCTAssertEqual(state.postIDs, Set(["ep1"]))
        XCTAssertEqual(state.anchorID, "ep1")
        XCTAssertEqual(state.count, 1)
    }

    func test_toggle_adds_and_removes() throws {
        var state = CollectionSelectionState()
        state.begin(with: try post("ep1"))

        state.toggle(try post("ep2"))
        XCTAssertEqual(state.postIDs, Set(["ep1", "ep2"]))
        XCTAssertEqual(state.anchorID, "ep2")

        state.toggle(try post("ep1"))
        XCTAssertEqual(state.postIDs, Set(["ep2"]))
        XCTAssertEqual(state.anchorID, "ep1")
    }

    func test_begin_and_toggle_ignore_non_playable_posts() throws {
        var state = CollectionSelectionState()

        state.begin(with: try post("text", type: "text_only"))
        XCTAssertFalse(state.isActive)
        XCTAssertTrue(state.postIDs.isEmpty)

        state.begin(with: try post("ep1"))
        state.toggle(try post("text", type: "text_only"))
        XCTAssertEqual(state.postIDs, Set(["ep1"]))
    }

    func test_select_all_only_includes_playable_posts() throws {
        var state = CollectionSelectionState()
        state.begin(with: try post("ep1"))

        state.selectAll(from: [
            try post("ep3"),
            try post("text", type: "text_only"),
            try post("locked", canView: false),
            try post("ep2"),
            try post("ep1"),
        ])

        XCTAssertEqual(state.postIDs, Set(["ep1", "ep2", "ep3"]))
    }

    func test_retain_drops_removed_posts() throws {
        var state = CollectionSelectionState()
        state.begin(with: try post("ep1"))
        state.toggle(try post("ep2"))
        state.toggle(try post("ep3"))

        state.retain(["ep1", "ep3"])

        XCTAssertEqual(state.postIDs, Set(["ep1", "ep3"]))
    }

    func test_end_clears_mode_and_selection() throws {
        var state = CollectionSelectionState()
        state.begin(with: try post("ep1"))
        state.toggle(try post("ep2"))

        state.end()

        XCTAssertFalse(state.isActive)
        XCTAssertTrue(state.postIDs.isEmpty)
        XCTAssertNil(state.anchorID)
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
