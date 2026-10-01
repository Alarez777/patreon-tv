//
//  CollectionDecodingTests.swift
//  PatreonTVTests
//
//  Decoding of a campaign's `collection` includes and their thumbnail variants.
//

import XCTest
@testable import PatreonTV

final class CollectionDecodingTests: XCTestCase {

    func test_decode_campaign_collections() throws {
        let json = """
        {
          "data": {
            "type": "campaign", "id": "13944363",
            "attributes": { "name": "DARU ANIME" },
            "relationships": { "collections": { "data": [ { "type": "collection", "id": "2338957" } ] } }
          },
          "included": [
            {
              "type": "collection",
              "id": "2338957",
              "attributes": {
                "title": "NARUTO SHIPPUDEN (Sin relleno)",
                "description": "Vemos Shippuden sin relleno!",
                "num_posts": 68,
                "post_ids": [171006271, 171000894],
                "post_sort_type": "custom",
                "thumbnail": {
                  "url": "https://c10.patreonusercontent.com/x.png",
                  "thumbnail": "https://c10.patreonusercontent.com/t100.png",
                  "thumbnail_large": "https://c10.patreonusercontent.com/t1080.png"
                }
              }
            }
          ]
        }
        """.data(using: .utf8)!

        let doc = try JSONAPIDecoder.decode(SingleResource<Campaign>.self, from: json)

        var collection: PatreonCollection?
        for inc in doc.included ?? [] {
            if case .collection(let c) = inc { collection = c }
        }

        XCTAssertEqual(collection?.id, "2338957")
        XCTAssertEqual(collection?.attributes.title, "NARUTO SHIPPUDEN (Sin relleno)")
        XCTAssertEqual(collection?.attributes.description, "Vemos Shippuden sin relleno!")
        XCTAssertEqual(collection?.attributes.numPosts, 68)
        XCTAssertEqual(collection?.attributes.postIDs, [171006271, 171000894])
        XCTAssertEqual(collection?.attributes.postSortType, "custom")
        XCTAssertEqual(
            collection?.attributes.thumbnail?.bestImageURL?.absoluteString,
            "https://c10.patreonusercontent.com/t1080.png"
        )
    }

    func test_collection_without_thumbnail_falls_back_nil() throws {
        let json = """
        {
          "data": { "type": "campaign", "id": "1", "attributes": { "name": "C" } },
          "included": [
            { "type": "collection", "id": "5", "attributes": { "title": "Empty" } }
          ]
        }
        """.data(using: .utf8)!

        let doc = try JSONAPIDecoder.decode(SingleResource<Campaign>.self, from: json)
        var collection: PatreonCollection?
        for inc in doc.included ?? [] {
            if case .collection(let c) = inc { collection = c }
        }

        XCTAssertEqual(collection?.id, "5")
        XCTAssertNil(collection?.attributes.thumbnail)
        XCTAssertNil(collection?.attributes.numPosts)
    }
}
