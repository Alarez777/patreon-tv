//
//  SessionIDParserTests.swift
//  PatreonTVTests
//
//  Accepts the shapes people paste from browser developer tools.
//

import XCTest
@testable import PatreonTV

final class SessionIDParserTests: XCTestCase {

    func test_accepts_bare_value() {
        XCTAssertEqual(SessionIDParser.parse("abc123"), "abc123")
    }

    func test_trims_whitespace_and_newlines() {
        XCTAssertEqual(SessionIDParser.parse("  abc123\n"), "abc123")
    }

    func test_extracts_from_cookie_pair() {
        XCTAssertEqual(
            SessionIDParser.parse("session_id=abc123; Path=/; HttpOnly"),
            "abc123"
        )
    }

    func test_extracts_from_cookie_header_with_other_cookies() {
        XCTAssertEqual(
            SessionIDParser.parse("foo=1; session_id=abc123; bar=2"),
            "abc123"
        )
    }

    func test_strips_quotes() {
        XCTAssertEqual(SessionIDParser.parse("\"abc123\""), "abc123")
        XCTAssertEqual(SessionIDParser.parse("'abc123'"), "abc123")
    }

    func test_rejects_empty_values() {
        XCTAssertNil(SessionIDParser.parse(""))
        XCTAssertNil(SessionIDParser.parse("   \n"))
        XCTAssertNil(SessionIDParser.parse("session_id=;"))
    }
}
