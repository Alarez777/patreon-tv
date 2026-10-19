//
//  CollectionSortTests.swift
//  PatreonTVTests
//
//  Ordering and filtering for a creator's collections.
//

import XCTest
@testable import PatreonTV

final class CollectionSortTests: XCTestCase {

    func test_creation_order_keeps_fetched_order() {
        let items = [collection("Beta"), collection("Alpha"), collection("Gamma")]
        XCTAssertEqual(
            CollectionSort.created.sorted(items).map(\.id),
            ["Beta", "Alpha", "Gamma"]
        )
    }

    func test_title_ascending_is_case_insensitive() {
        let items = [collection("beta"), collection("Alpha"), collection("gamma")]
        XCTAssertEqual(
            CollectionSort.titleAscending.sorted(items).map(\.id),
            ["Alpha", "beta", "gamma"]
        )
    }

    func test_title_descending() {
        let items = [collection("beta"), collection("Alpha"), collection("gamma")]
        XCTAssertEqual(
            CollectionSort.titleDescending.sorted(items).map(\.id),
            ["gamma", "beta", "Alpha"]
        )
    }

    func test_title_sort_is_stable_for_equal_titles() {
        let items = [
            makeCollection(id: "1", title: "Same"),
            makeCollection(id: "2", title: "same"),
        ]
        XCTAssertEqual(
            CollectionSort.titleAscending.sorted(items).map(\.id),
            ["1", "2"]
        )
    }

    func test_search_matches_title_and_description() {
        let items = [
            collection("Updates", description: "Behind the scenes"),
            collection("Tutorials"),
        ]

        XCTAssertEqual(CollectionSearch.filter(items, query: "updates").map(\.id), ["Updates"])
        XCTAssertEqual(CollectionSearch.filter(items, query: "behind").map(\.id), ["Updates"])
        XCTAssertEqual(CollectionSearch.filter(items, query: "tutor").map(\.id), ["Tutorials"])
    }

    func test_search_is_diacritic_and_case_insensitive() {
        let items = [collection("Café", description: "Résumé")]
        XCTAssertEqual(CollectionSearch.filter(items, query: "cafe").map(\.id), ["Café"])
        XCTAssertEqual(CollectionSearch.filter(items, query: "resume").map(\.id), ["Café"])
    }

    func test_empty_query_returns_all_collections() {
        let items = [collection("One"), collection("Two")]
        XCTAssertEqual(CollectionSearch.filter(items, query: "   ").map(\.id), ["One", "Two"])
    }

    func test_no_match_returns_empty() {
        let items = [collection("One"), collection("Two")]
        XCTAssertTrue(CollectionSearch.filter(items, query: "missing").isEmpty)
    }

    // MARK: - Helpers

    private func collection(_ title: String, description: String? = nil) -> PatreonCollection {
        makeCollection(id: title, title: title, description: description)
    }

    private func makeCollection(
        id: String,
        title: String,
        description: String? = nil
    ) -> PatreonCollection {
        PatreonCollection(
            id: id,
            type: "collection",
            attributes: PatreonCollection.Attributes(
                title: title,
                description: description,
                numPosts: nil,
                postIDs: nil,
                postSortType: nil,
                thumbnail: nil
            )
        )
    }
}
