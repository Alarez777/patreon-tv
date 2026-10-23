//
//  AuthStoreTests.swift
//  PatreonTVTests
//
//  The session-clearing policy: only a definitive credential rejection
//  (401/403) may destroy the stored session. Transient failures — offline,
//  outage, rate limit, decode drift — must keep it.
//

import XCTest
@testable import PatreonTV

final class AuthStoreTests: XCTestCase {

    func test_clears_session_only_on_credential_rejection() {
        XCTAssertTrue(AuthStore.shouldClearSession(after: PatreonError.unauthorized))
        XCTAssertTrue(AuthStore.shouldClearSession(after: PatreonError.forbidden))
    }

    func test_maps_sign_in_errors() {
        XCTAssertEqual(
            AuthStore.signInError(from: PatreonError.unauthorized),
            .invalidSession
        )
        XCTAssertEqual(
            AuthStore.signInError(from: PatreonError.forbidden),
            .invalidSession
        )
        XCTAssertEqual(
            AuthStore.signInError(from: PatreonError.rateLimited(retryAfterSeconds: 30)),
            .rateLimited(retryAfter: 30)
        )
        XCTAssertEqual(
            AuthStore.signInError(from: URLError(.notConnectedToInternet)),
            .network
        )
        XCTAssertEqual(
            AuthStore.signInError(from: PatreonError.decoding(underlying: URLError(.cannotParseResponse))),
            .unexpected
        )
    }

    func test_keeps_session_on_transient_errors() {
        XCTAssertFalse(AuthStore.shouldClearSession(after: URLError(.notConnectedToInternet)))
        XCTAssertFalse(AuthStore.shouldClearSession(after: URLError(.timedOut)))
        XCTAssertFalse(AuthStore.shouldClearSession(after: PatreonError.rateLimited(retryAfterSeconds: 60)))
        XCTAssertFalse(AuthStore.shouldClearSession(after: PatreonError.http(status: 503, body: "")))
        XCTAssertFalse(AuthStore.shouldClearSession(after: PatreonError.badResponse))
        XCTAssertFalse(AuthStore.shouldClearSession(
            after: PatreonError.decoding(underlying: URLError(.cannotParseResponse))
        ))
    }

    // MARK: - Sign-out

    @MainActor
    func test_sign_out_removes_the_stored_session() async {
        let storage = InMemorySessionStorage()
        storage.values[AuthStore.sessionKey] = "session-cookie"
        storage.values[AuthStore.userIDKey] = "42"

        let store = AuthStore(storage: storage)
        await store.signOut()

        XCTAssertNil(storage.string(forKey: AuthStore.sessionKey))
        XCTAssertNil(storage.string(forKey: AuthStore.userIDKey))
        XCTAssertEqual(store.state, .signedOut)
    }
}

private final class InMemorySessionStorage: SessionStorage {

    var values: [String: String] = [:]

    func set(_ value: String, forKey key: String) -> Bool {
        values[key] = value
        return true
    }

    func string(forKey key: String) -> String? {
        values[key]
    }

    func remove(forKey key: String) {
        values.removeValue(forKey: key)
    }
}
