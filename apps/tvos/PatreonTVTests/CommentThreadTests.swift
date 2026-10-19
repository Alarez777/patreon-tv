//
//  CommentThreadTests.swift
//  PatreonTVTests
//
//  Flattening of top-level comments plus expanded replies.
//

import XCTest
@testable import PatreonTV

final class CommentThreadTests: XCTestCase {

    func test_collapsed_hides_loaded_replies() {
        let a = comment("a", replyCount: 2)
        let b = comment("b")
        let items = CommentThread.flatten(
            roots: [a, b],
            replies: ["a": [comment("r1"), comment("r2")]],
            expandedReplies: [],
            expandedText: [],
            authorByID: [:]
        )

        XCTAssertEqual(items.map(\.id), ["a", "b"])
        XCTAssertEqual(items.map(\.depth), [0, 0])
        XCTAssertEqual(items.map(\.parentID), [nil, nil])
        XCTAssertEqual(items.map(\.isRepliesExpanded), [false, false])
    }

    func test_expanded_nests_replies_under_parent() {
        let a = comment("a", replyCount: 2)
        let b = comment("b")
        let items = CommentThread.flatten(
            roots: [a, b],
            replies: ["a": [comment("r1"), comment("r2")]],
            expandedReplies: ["a"],
            expandedText: [],
            authorByID: [:]
        )

        XCTAssertEqual(items.map(\.id), ["a", "r1", "r2", "b"])
        XCTAssertEqual(items.map(\.depth), [0, 1, 1, 0])
        XCTAssertEqual(items.map(\.parentID), [nil, "a", "a", nil])
        XCTAssertEqual(items.map(\.isLastSibling), [false, false, true, true])
        XCTAssertEqual(items.map(\.isRepliesExpanded), [true, false, false, false])
    }

    func test_expansion_is_recursive() {
        let a = comment("a", replyCount: 1)
        let items = CommentThread.flatten(
            roots: [a],
            replies: [
                "a": [comment("r1", replyCount: 1)],
                "r1": [comment("rr1")],
            ],
            expandedReplies: ["a", "r1"],
            expandedText: [],
            authorByID: [:]
        )

        XCTAssertEqual(items.map(\.id), ["a", "r1", "rr1"])
        XCTAssertEqual(items.map(\.depth), [0, 1, 2])
    }

    func test_reply_resolves_parent_author() {
        let a = comment("a", replyCount: 1)
        let reply = comment("r1", parent: "a")
        let alice = user("Alice")
        let items = CommentThread.flatten(
            roots: [a],
            replies: ["a": [reply]],
            expandedReplies: ["a"],
            expandedText: [],
            authorByID: ["a": alice]
        )

        XCTAssertEqual(items.last?.parentAuthor?.attributes.fullName, "Alice")
    }

    func test_text_expansion_is_independent_from_replies() {
        let a = comment("a", replyCount: 1)
        let items = CommentThread.flatten(
            roots: [a],
            replies: ["a": [comment("r1")]],
            expandedReplies: [],
            expandedText: ["a"],
            authorByID: [:]
        )

        XCTAssertEqual(items.map(\.id), ["a"])
        XCTAssertEqual(items.first?.isTextExpanded, true)
        XCTAssertEqual(items.first?.isRepliesExpanded, false)
    }

    // MARK: - Helpers

    private func comment(
        _ id: String,
        created: String = "2026-01-01T00:00:00.000+00:00",
        replyCount: Int = 0,
        parent: String? = nil
    ) -> Comment {
        Comment(
            id: id,
            type: "comment",
            attributes: Comment.Attributes(
                body: id,
                created: created,
                deletedAt: nil,
                isByCreator: nil,
                isByPatron: nil,
                isLikedByCreator: nil,
                visibilityState: nil,
                voteSum: nil,
                replyCount: replyCount
            ),
            relationships: Comment.Relationships(
                commenter: nil,
                parent: parent.map { RelationRef(data: RelationID(type: "comment", id: $0)) }
            )
        )
    }

    private func user(_ name: String) -> PatreonUser {
        PatreonUser(
            id: name.lowercased(),
            type: "user",
            attributes: PatreonUser.Attributes(
                fullName: name,
                email: nil,
                imageURL: nil,
                thumbURL: nil,
                isCreator: nil,
                vanity: nil,
                url: nil
            )
        )
    }
}
