//
//  CreatorPostFilterTests.swift
//  PatreonTVTests
//
//  Mapping between the creator content-type filter, the API post types and the
//  campaign's post_count breakdown.
//

import XCTest
@testable import PatreonTV

final class CreatorPostFilterTests: XCTestCase {

    func test_post_types_per_filter() {
        XCTAssertTrue(CreatorPostFilter.all.postTypes.isEmpty)
        XCTAssertEqual(CreatorPostFilter.videos.postTypes, [.videoExternalFile, .videoEmbed])
        XCTAssertEqual(CreatorPostFilter.audio.postTypes, [.audioFile, .audioEmbed])
        XCTAssertEqual(CreatorPostFilter.images.postTypes, [.imageFile])
        XCTAssertEqual(CreatorPostFilter.text.postTypes, [.textOnly])
        XCTAssertEqual(CreatorPostFilter.podcasts.postTypes, [.podcast])
        XCTAssertEqual(CreatorPostFilter.polls.postTypes, [.poll])
    }

    func test_counts_from_post_count() {
        let counts = Campaign.PostCount(
            total: 10, video: 6, image: 4, text: 0,
            audio: 0, podcast: 0, poll: 0, link: 0, livestream: 0
        )
        XCTAssertEqual(CreatorPostFilter.all.count(in: counts), 10)
        XCTAssertEqual(CreatorPostFilter.videos.count(in: counts), 6)
        XCTAssertEqual(CreatorPostFilter.images.count(in: counts), 4)
        XCTAssertEqual(CreatorPostFilter.text.count(in: counts), 0)
        XCTAssertNil(CreatorPostFilter.videos.count(in: nil))
    }
}
