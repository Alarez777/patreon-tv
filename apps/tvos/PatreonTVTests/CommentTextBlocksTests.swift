//
//  CommentTextBlocksTests.swift
//  PatreonTVTests
//
//  Chunking of long comment bodies into focusable reading blocks.
//

import XCTest
@testable import PatreonTV

final class CommentTextBlocksTests: XCTestCase {

    func test_short_text_is_one_block() {
        let text = AttributedString("A short comment.")
        let blocks = CommentTextBlocks.split(text, maxCharacters: 60)

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(String(blocks[0].characters), "A short comment.")
    }

    func test_empty_text_has_no_blocks() {
        XCTAssertTrue(CommentTextBlocks.split(AttributedString(), maxCharacters: 60).isEmpty)
    }

    func test_long_text_splits_at_word_boundaries() {
        let words = (1...80).map { "word\($0)" }
        let text = AttributedString(words.joined(separator: " "))
        let blocks = CommentTextBlocks.split(text, maxCharacters: 60)

        XCTAssertGreaterThan(blocks.count, 1)
        XCTAssertEqual(blocks.map { String($0.characters) }.joined(), String(text.characters))
        for block in blocks {
            XCTAssertLessThanOrEqual(block.characters.count, 60)
        }

        // Every block starts at a word, never mid-word or with whitespace.
        for block in blocks {
            let first = block.characters.first ?? " "
            XCTAssertFalse(first.isWhitespace)
        }
    }

    func test_single_giant_word_is_hard_split() {
        let text = AttributedString(String(repeating: "a", count: 150))
        let blocks = CommentTextBlocks.split(text, maxCharacters: 50)

        XCTAssertEqual(blocks.map { $0.characters.count }, [50, 50, 50])
        XCTAssertEqual(blocks.map { String($0.characters) }.joined(), String(text.characters))
    }

    func test_attributes_are_preserved() throws {
        var text = AttributedString("Alpha beta gamma delta epsilon zeta eta theta")
        let url = try XCTUnwrap(URL(string: "https://example.com"))
        text.link = url

        let blocks = CommentTextBlocks.split(text, maxCharacters: 20)

        XCTAssertGreaterThan(blocks.count, 1)
        for block in blocks {
            XCTAssertEqual(block.link, url)
        }
    }

    func test_lines_become_separate_blocks() {
        let text = AttributedString("first line\nsecond line\n\nthird line")
        let blocks = CommentTextBlocks.split(text, maxCharacters: 100)

        XCTAssertEqual(blocks.map { String($0.characters) }, ["first line", "second line", "third line"])
        XCTAssertFalse(blocks.contains { String($0.characters).contains("\n") })
    }

    func test_long_line_is_split_but_other_lines_stay_whole() {
        let longLine = (1...40).map { "word\($0)" }.joined(separator: " ")
        let text = AttributedString("intro\n\(longLine)\noutro")
        let blocks = CommentTextBlocks.split(text, maxCharacters: 60)

        XCTAssertEqual(String(blocks.first?.characters ?? ""), "intro")
        XCTAssertEqual(String(blocks.last?.characters ?? ""), "outro")
        XCTAssertGreaterThan(blocks.count, 3)
        for block in blocks {
            XCTAssertFalse(String(block.characters).contains("\n"))
        }
    }
}
