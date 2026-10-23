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
        /// The collection's creator (campaign) name, when known.
        let campaignName: String?
        /// When this snapshot was fetched, so screens can revalidate silently.
        let fetchedAt: Date
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

    func store(
        collection: PatreonCollection,
        posts: [Post],
        campaignName: String? = nil,
        fetchedAt: Date = Date()
    ) {
        let id = collection.id
        // Don't clobber a known creator name when a caller doesn't have it.
        let resolvedName = campaignName ?? store[id]?.campaignName
        store[id] = Snapshot(
            collection: collection,
            posts: posts,
            campaignName: resolvedName,
            fetchedAt: fetchedAt
        )
        order.removeAll { $0 == id }
        order.append(id)
        while order.count > limit {
            store[order.removeFirst()] = nil
        }
    }

    /// Drops every snapshot. Used when the user clears the cache or signs out.
    func clear() {
        store.removeAll()
        order.removeAll()
    }
}
