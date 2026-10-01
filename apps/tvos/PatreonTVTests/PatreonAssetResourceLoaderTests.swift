//
//  PatreonAssetResourceLoaderTests.swift
//  PatreonTVTests
//
//  Host scoping for the playback cookie. The security guarantee is that the
//  Patreon session cookie is attached to patreon.com hosts only and never to
//  the Mux/Patreon CDNs, so these tests pin the host predicate and the
//  redirect-stripping behaviour.
//

import Foundation
import XCTest
@testable import PatreonTV

final class PatreonAssetResourceLoaderTests: XCTestCase {

    func test_isPatreonHost_acceptsPatreonAndSubdomains() {
        XCTAssertTrue(PatreonAssetResourceLoader.isPatreonHost("patreon.com"))
        XCTAssertTrue(PatreonAssetResourceLoader.isPatreonHost("www.patreon.com"))
        XCTAssertTrue(PatreonAssetResourceLoader.isPatreonHost("c10.patreon.com"))
        XCTAssertTrue(PatreonAssetResourceLoader.isPatreonHost("WWW.PATREON.COM"))
    }

    func test_isPatreonHost_rejectsCdnAndLookalikes() {
        XCTAssertFalse(PatreonAssetResourceLoader.isPatreonHost("stream.mux.com"))
        XCTAssertFalse(PatreonAssetResourceLoader.isPatreonHost("c10.patreonusercontent.com"))
        XCTAssertFalse(PatreonAssetResourceLoader.isPatreonHost("notpatreon.com"))
        XCTAssertFalse(PatreonAssetResourceLoader.isPatreonHost("patreon.com.evil.example"))
        XCTAssertFalse(PatreonAssetResourceLoader.isPatreonHost(nil))
    }

    func test_strippingCookie_keepsCookieForPatreonHost() {
        var request = URLRequest(url: URL(string: "https://www.patreon.com/api/video/1/manifest.m3u8")!)
        request.setValue("session_id=secret", forHTTPHeaderField: "Cookie")

        let result = PatreonAssetResourceLoader.strippingCookieIfNeeded(from: request)

        XCTAssertEqual(result.value(forHTTPHeaderField: "Cookie"), "session_id=secret")
    }

    func test_strippingCookie_removesCookieOffPatreonHost() {
        var request = URLRequest(url: URL(string: "https://stream.mux.com/abc.m3u8?token=t")!)
        request.setValue("session_id=secret", forHTTPHeaderField: "Cookie")

        let result = PatreonAssetResourceLoader.strippingCookieIfNeeded(from: request)

        XCTAssertNil(result.value(forHTTPHeaderField: "Cookie"))
    }

    func test_strippingCookie_removesCookieFromPatreonUserContent() {
        var request = URLRequest(url: URL(string: "https://c10.patreonusercontent.com/file.mp4?token=x")!)
        request.setValue("session_id=secret", forHTTPHeaderField: "Cookie")

        let result = PatreonAssetResourceLoader.strippingCookieIfNeeded(from: request)

        XCTAssertNil(result.value(forHTTPHeaderField: "Cookie"))
    }
}
