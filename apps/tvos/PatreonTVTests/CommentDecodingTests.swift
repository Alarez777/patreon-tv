//
//  CommentDecodingTests.swift
//  PatreonTVTests
//
//  Decoding of post comments, including reply parents and like counts.
//

import XCTest
@testable import PatreonTV

final class CommentDecodingTests: XCTestCase {

    func test_decodes_comments_and_reply_parent() throws {
        let json = """
        {
          "data": [
            {
              "type": "comment", "id": "c1",
              "attributes": {
                "body": "Top", "created": "2026-01-01T00:00:00.000+00:00",
                "vote_sum": 2, "is_by_creator": false, "is_by_patron": true
              },
              "relationships": {
                "commenter": { "data": { "type": "user", "id": "u1" } },
                "parent": { "data": null }
              }
            },
            {
              "type": "comment", "id": "c2",
              "attributes": {
                "body": "Reply", "created": "2026-01-01T00:01:00.000+00:00",
                "vote_sum": 0
              },
              "relationships": {
                "commenter": { "data": { "type": "user", "id": "u2" } },
                "parent": { "data": { "type": "comment", "id": "c1" } }
              }
            }
          ],
          "included": [
            { "type": "user", "id": "u1", "attributes": { "full_name": "One" } },
            { "type": "user", "id": "u2", "attributes": { "full_name": "Two" } }
          ],
          "meta": { "count": 2 }
        }
        """.data(using: .utf8)!

        let page = try JSONAPIDecoder.decode(Page<Comment>.self, from: json)

        XCTAssertEqual(page.data.count, 2)
        XCTAssertEqual(page.data.first?.attributes.body, "Top")
        XCTAssertEqual(page.data.first?.attributes.voteSum, 2)
        XCTAssertNil(page.data.first?.relationships?.parent?.data?.id)
        XCTAssertEqual(page.data.last?.relationships?.parent?.data?.id, "c1")
        XCTAssertEqual(page.meta?.count, 2)
    }
}
