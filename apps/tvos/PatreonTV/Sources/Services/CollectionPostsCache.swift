//
//  CollectionPostsCache.swift
//  PatreonTV
//
//  In-memory cache of a collection (its metadata and ordered posts). Opening a
//  collection warms it, so returning to the screen — or opening an episode from
//  it — renders instantly instead of re-fetching.
//

import Foundation

@MainActor
final class CollectionPostsCache {

    static let shared = CollectionPostsCache()

    struct Snapshot {
        let collection: PatreonCollection
        let posts: [Post]
    }

    private var store: [String: Snapshot] = [:]
    private var order: [String] = []
    private let limit = 8

    func snapshot(for collectionID: String) -> Snapshot? {
        store[collectionID]
    }

    func posts(for collectionID: String) -> [Post]? {
        store[collectionID]?.posts
    }

    func store(collection: PatreonCollection, posts: [Post]) {
        let id = collection.id
        store[id] = Snapshot(collection: collection, posts: posts)
        order.removeAll { $0 == id }
        order.append(id)
        while order.count > limit {
            store[order.removeFirst()] = nil
        }
    }
}
