//
//  PostPayloadDecodingTests.swift
//  PatreonTVTests
//
//  Decoding of the poll and image resources that ride along in a post
//  document's `included` array.
//

import XCTest
@testable import PatreonTV

final class PostPayloadDecodingTests: XCTestCase {

    func test_decodes_poll_choices_and_vote() throws {
        let json = """
        {
          "data": {
            "type": "post", "id": "1",
            "attributes": { "post_type": "poll", "title": "Q" },
            "relationships": { "poll": { "data": { "type": "poll", "id": "p1" } } }
          },
          "included": [
            {
              "type": "poll", "id": "p1",
              "attributes": { "question_text": "Q", "question_type": "single_choice", "num_responses": 10, "closes_at": null },
              "relationships": {
                "choices": { "data": [ { "type": "poll_choice", "id": "c1" }, { "type": "poll_choice", "id": "c2" } ] },
                "current_user_responses": { "data": [ { "type": "poll_response", "id": "r1" } ] }
              }
            },
            { "type": "poll_choice", "id": "c1", "attributes": { "text_content": "A", "position": 1, "num_responses": 6 } },
            { "type": "poll_choice", "id": "c2", "attributes": { "text_content": "B", "position": 2, "num_responses": 4 } },
            {
              "type": "poll_response", "id": "r1",
              "attributes": { "responded_at": "2026-01-01T00:00:00.000+00:00", "text_content": null },
              "relationships": { "choice": { "data": { "type": "poll_choice", "id": "c2" } } }
            }
          ]
        }
        """.data(using: .utf8)!

        let doc = try JSONAPIDecoder.decode(SingleResource<Post>.self, from: json)
        XCTAssertEqual(doc.data.attributes.postType, Post.PostType.poll)

        let included = doc.included ?? []
        let poll = included.compactMap { inc -> Poll? in
            if case .poll(let poll) = inc { return poll }
            return nil
        }.first
        XCTAssertEqual(poll?.attributes.questionText, "Q")
        XCTAssertEqual(poll?.attributes.questionType, "single_choice")
        XCTAssertEqual(poll?.attributes.numResponses, 10)

        let choices = included.compactMap { inc -> PollChoice? in
            if case .pollChoice(let choice) = inc { return choice }
            return nil
        }.sorted { ($0.attributes.position ?? 0) < ($1.attributes.position ?? 0) }
        XCTAssertEqual(choices.map(\.attributes.textContent), ["A", "B"])
        XCTAssertEqual(choices.map(\.attributes.numResponses), [6, 4])

        let selected = Set(included.compactMap { inc -> String? in
            guard case .pollResponse(let response) = inc else { return nil }
            return response.relationships?.choice?.data?.id
        })
        XCTAssertEqual(selected, ["c2"])
    }

    func test_decodes_image_post_and_media_image_urls() throws {
        let json = """
        {
          "data": {
            "type": "post", "id": "2",
            "attributes": {
              "post_type": "image_file", "title": "Pics",
              "image": { "url": "https://cdn.example/a.png", "thumb_url": "https://cdn.example/at.png", "large_url": "https://cdn.example/al.png", "width": 1000, "height": 500 }
            },
            "relationships": { "images": { "data": [ { "type": "media", "id": "m1" }, { "type": "media", "id": "m2" } ] } }
          },
          "included": [
            { "type": "media", "id": "m1", "attributes": { "image_urls": { "url": "https://cdn.example/m1.png", "original": "https://cdn.example/m1-orig.png", "default_large": "https://cdn.example/m1-large.png" } } },
            { "type": "media", "id": "m2", "attributes": { "image_urls": { "url": "https://cdn.example/m2.png", "original": "https://cdn.example/m2-orig.png", "default_large": "https://cdn.example/m2-large.png" } } }
          ]
        }
        """.data(using: .utf8)!

        let doc = try JSONAPIDecoder.decode(SingleResource<Post>.self, from: json)
        XCTAssertEqual(doc.data.attributes.postType, Post.PostType.imageFile)
        XCTAssertEqual(doc.data.attributes.image?.largeURL?.absoluteString, "https://cdn.example/al.png")
        XCTAssertEqual(doc.data.relationships?.images?.data?.map(\.id), ["m1", "m2"])
        XCTAssertEqual(doc.data.imageCount, 2)

        let media = (doc.included ?? []).compactMap { inc -> Media? in
            if case .media(let media) = inc { return media }
            return nil
        }
        XCTAssertEqual(media.first?.attributes.imageURLs?.original?.absoluteString, "https://cdn.example/m1-orig.png")
    }

    func test_single_image_still_counts_as_an_image_post() throws {
        let json = """
        {
          "data": {
            "type": "post", "id": "3",
            "attributes": {
              "post_type": "image_file",
              "image": { "url": "https://cdn.example/one.png" }
            },
            "relationships": {
              "images": { "data": [ { "type": "media", "id": "m1" } ] }
            }
          }
        }
        """.data(using: .utf8)!

        let doc = try JSONAPIDecoder.decode(SingleResource<Post>.self, from: json)
        XCTAssertEqual(doc.data.imageCount, 1)
    }
}
