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

    private var collectionsByCampaign: [String: [PatreonCollection]] = [:]

    private init() {}

    func store(_ collections: [PatreonCollection], for campaignID: String) {
        collectionsByCampaign[campaignID] = collections
    }

    func collections(for campaignID: String) -> [PatreonCollection]? {
        collectionsByCampaign[campaignID]
    }
}
