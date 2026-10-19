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
        let blocks = CommentTextBlocks.split(text, maxLines: 20, maxCharacters: 60)

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(String(blocks[0].characters), "A short comment.")
    }

    func test_empty_text_has_no_blocks() {
        XCTAssertTrue(CommentTextBlocks.split(AttributedString(), maxLines: 20, maxCharacters: 60).isEmpty)
    }

    func test_lines_stay_together_in_one_block() {
        let text = AttributedString("first line\nsecond line\n\nthird line")
        let blocks = CommentTextBlocks.split(text, maxLines: 20, maxCharacters: 1000)

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(String(blocks[0].characters), "first line\nsecond line\n\nthird line")
    }

    func test_more_than_max_lines_splits_into_blocks() {
        let lines = (1...25).map { "line \($0)" }
        let text = AttributedString(lines.joined(separator: "\n"))
        let blocks = CommentTextBlocks.split(text, maxLines: 20, maxCharacters: 10_000)

        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(String(blocks[0].characters).split(separator: "\n").count, 20)
        XCTAssertEqual(String(blocks[1].characters).split(separator: "\n").count, 5)
    }

    func test_long_text_splits_at_word_boundaries() {
        let words = (1...80).map { "word\($0)" }
        let text = AttributedString(words.joined(separator: " "))
        let blocks = CommentTextBlocks.split(text, maxLines: 20, maxCharacters: 60)

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

    func test_sentence_punctuation_is_preferred() {
        let text = AttributedString("One two three. Four five six seven eight nine ten.")
        let blocks = CommentTextBlocks.split(text, maxLines: 20, maxCharacters: 20)

        XCTAssertTrue(String(blocks[0].characters).hasPrefix("One two three."))
        XCTAssertFalse(String(blocks[0].characters).contains("Four"))
    }

    func test_clause_punctuation_is_used_without_sentence_end() {
        let text = AttributedString("One two three, four five six seven eight nine ten.")
        let blocks = CommentTextBlocks.split(text, maxLines: 20, maxCharacters: 20)

        XCTAssertTrue(String(blocks[0].characters).hasPrefix("One two three,"))
        XCTAssertFalse(String(blocks[0].characters).contains("four"))
    }

    func test_list_marker_starts_new_block_near_limit() {
        var lines = Array(repeating: "plain line", count: 18)
        lines.append("- list item")
        lines.append("tail")
        let text = AttributedString(lines.joined(separator: "\n"))
        let blocks = CommentTextBlocks.split(text, maxLines: 20, maxCharacters: 10_000)

        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(String(blocks[0].characters).split(separator: "\n").count, 18)
        XCTAssertTrue(String(blocks[1].characters).hasPrefix("- list item"))
    }

    func test_heading_starts_new_block_near_limit() {
        var lines = Array(repeating: "plain line", count: 18)
        lines.append("# Heading")
        lines.append("body")
        let text = AttributedString(lines.joined(separator: "\n"))
        let blocks = CommentTextBlocks.split(text, maxLines: 20, maxCharacters: 10_000)

        XCTAssertEqual(blocks.count, 2)
        XCTAssertTrue(String(blocks[1].characters).hasPrefix("# Heading"))
    }

    func test_single_giant_word_is_hard_split() {
        let text = AttributedString(String(repeating: "a", count: 150))
        let blocks = CommentTextBlocks.split(text, maxLines: 20, maxCharacters: 50)

        XCTAssertEqual(blocks.map { $0.characters.count }, [50, 50, 50])
        XCTAssertEqual(blocks.map { String($0.characters) }.joined(), String(text.characters))
    }

    func test_attributes_are_preserved() throws {
        var text = AttributedString("Alpha beta gamma delta epsilon zeta eta theta")
        let url = try XCTUnwrap(URL(string: "https://example.com"))
        text.link = url

        let blocks = CommentTextBlocks.split(text, maxLines: 20, maxCharacters: 20)

        XCTAssertGreaterThan(blocks.count, 1)
        for block in blocks {
            XCTAssertEqual(block.link, url)
        }
    }
}
