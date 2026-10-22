//
//  CollectionsCache.swift
//  PatreonTV
//
//  Session cache for collections already loaded by a creator's Collections
//  screen. The search route only carries a campaign id, so it reads this cache
//  instead of fetching the same list again.
//

import Foundation

@MainActor
final class CollectionsCache {

    static let shared = CollectionsCache()

    struct Snapshot {
        let collections: [PatreonCollection]
        /// When this list was fetched, so screens can revalidate silently.
        let fetchedAt: Date
    }

    private var snapshotsByCampaign: [String: Snapshot] = [:]

    private init() {}

    func store(
        _ collections: [PatreonCollection],
        for campaignID: String,
        fetchedAt: Date = Date()
    ) {
        snapshotsByCampaign[campaignID] = Snapshot(
            collections: collections,
            fetchedAt: fetchedAt
        )
    }

    func collections(for campaignID: String) -> [PatreonCollection]? {
        snapshotsByCampaign[campaignID]?.collections
    }

    func fetchedAt(for campaignID: String) -> Date? {
        snapshotsByCampaign[campaignID]?.fetchedAt
    }
}
