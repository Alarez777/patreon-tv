//
//  ProseMirrorRendererTests.swift
//  PatreonTVTests
//
//  Flattening of Patreon's `content_json_string` (ProseMirror) post bodies.
//

import XCTest
@testable import PatreonTV

final class ProseMirrorRendererTests: XCTestCase {

    func test_paragraphs_become_lines() {
        let json = #"{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"Hola"}]},{"type":"paragraph","content":[{"type":"text","text":"Mundo"}]}]}"#
        XCTAssertEqual(ProseMirrorRenderer.plainText(from: json), "Hola\nMundo")
    }

    func test_hard_break() {
        let json = #"{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"A"},{"type":"hard_break"},{"type":"text","text":"B"}]}]}"#
        XCTAssertEqual(ProseMirrorRenderer.plainText(from: json), "A\nB")
    }

    func test_bullet_list() {
        let json = #"{"type":"doc","content":[{"type":"bullet_list","content":[{"type":"list_item","content":[{"type":"paragraph","content":[{"type":"text","text":"Uno"}]}]},{"type":"list_item","content":[{"type":"paragraph","content":[{"type":"text","text":"Dos"}]}]}]}]}"#
        XCTAssertEqual(ProseMirrorRenderer.plainText(from: json), "• Uno\n• Dos")
    }

    func test_empty_doc_returns_nil() {
        XCTAssertNil(ProseMirrorRenderer.plainText(from: #"{"type":"doc","content":[]}"#))
    }

    func test_invalid_json_returns_nil() {
        XCTAssertNil(ProseMirrorRenderer.plainText(from: "not json"))
    }
}
