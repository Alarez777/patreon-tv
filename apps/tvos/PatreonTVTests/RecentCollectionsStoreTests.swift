//
//  RecentCollectionsStoreTests.swift
//  PatreonTVTests
//
//  Follow/unfollow semantics for Continue Collection.
//

import XCTest
@testable import PatreonTV

@MainActor
final class RecentCollectionsStoreTests: XCTestCase {

    func test_record_inserts_newest_first_and_moves_existing_to_front() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = RecentCollectionsStore(defaults: defaults)
        store.record(collection("a"))
        store.record(collection("b"))
        store.record(collection("a"))

        XCTAssertEqual(store.recent(limit: 10).map(\.id), ["a", "b"])
        XCTAssertTrue(store.isTracked(id: "a"))
    }

    func test_record_trims_to_max_entries() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = RecentCollectionsStore(defaults: defaults)
        for index in 0...10 {
            store.record(collection("\(index)"))
        }

        XCTAssertEqual(store.recent(limit: 20).count, 10)
        XCTAssertEqual(store.recent(limit: 20).first?.id, "10")
        XCTAssertFalse(store.isTracked(id: "0"))
    }

    func test_temporary_remove_returns_after_record() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = RecentCollectionsStore(defaults: defaults)
        store.record(collection("a"))
        store.remove(id: "a")
        XCTAssertFalse(store.isTracked(id: "a"))

        store.record(collection("a"))
        XCTAssertTrue(store.isTracked(id: "a"))
    }

    func test_permanent_hide_survives_record_until_added_back() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = RecentCollectionsStore(defaults: defaults)
        store.record(collection("a"))
        store.hide(id: "a")
        XCTAssertFalse(store.isTracked(id: "a"))

        store.record(collection("a"))
        XCTAssertFalse(store.isTracked(id: "a"))

        store.add(collection("a"))
        XCTAssertTrue(store.isTracked(id: "a"))
    }

    func test_persistence_round_trip() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = RecentCollectionsStore(defaults: defaults)
        first.record(collection("a"))
        first.record(collection("b"))
        first.hide(id: "b")

        let second = RecentCollectionsStore(defaults: defaults)
        XCTAssertTrue(second.isTracked(id: "a"))
        XCTAssertFalse(second.isTracked(id: "b"))

        second.record(collection("b"))
        XCTAssertFalse(second.isTracked(id: "b"), "permanent hides must survive relaunch")
    }

    func test_add_clears_permanent_hide_across_launches() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let first = RecentCollectionsStore(defaults: defaults)
        first.hide(id: "a")

        let second = RecentCollectionsStore(defaults: defaults)
        second.add(collection("a"))

        XCTAssertTrue(second.isTracked(id: "a"))
        XCTAssertTrue(RecentCollectionsStore(defaults: defaults).isTracked(id: "a"))
    }

    // MARK: - Helpers

    private func makeDefaults() -> (UserDefaults, String) {
        let suite = "RecentCollectionsStoreTests.\(UUID().uuidString)"
        return (UserDefaults(suiteName: suite)!, suite)
    }

    private func collection(_ id: String) -> RecentCollection {
        RecentCollection(
            id: id,
            title: id,
            squareImageURL: nil,
            wideImageURL: nil,
            numPosts: nil,
            campaignName: nil,
            nextEpisodeTitle: nil
        )
    }
}
