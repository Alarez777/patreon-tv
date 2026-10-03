//
//  CollectionPostsCache.swift
//  PatreonTV
//
//  In-memory cache of a collection's ordered posts. Opening an episode from a
//  collection warms it, so the post detail's episode strip doesn't re-fetch the
//  whole collection.
//

import Foundation

@MainActor
final class CollectionPostsCache {

    static let shared = CollectionPostsCache()

    private var store: [String: [Post]] = [:]
    private var order: [String] = []
    private let limit = 8

    func posts(for collectionID: String) -> [Post]? {
        store[collectionID]
    }

    func store(_ posts: [Post], for collectionID: String) {
        store[collectionID] = posts
        order.removeAll { $0 == collectionID }
        order.append(collectionID)
        while order.count > limit {
            store[order.removeFirst()] = nil
        }
    }
}
