//
//  RecentCollectionsStore.swift
//  PatreonTV
//
//  Remembers the collections the user opened recently, so Home can offer a
//  "Continue Collection" shelf. Metadata is cached with each entry so the shelf
//  renders without a network round-trip.
//

import Foundation
import Observation

struct RecentCollection: Codable, Identifiable {
    let id: String
    let title: String
    /// Square art (fallback for the shelf card).
    let squareImageURL: URL?
    /// Wide 16:9-ish art, used for the Home shelf card.
    let wideImageURL: URL?
    let numPosts: Int?
}

@MainActor
@Observable
final class RecentCollectionsStore {

    static let shared = RecentCollectionsStore()

    // v2: collections are only recorded once something in them has been watched,
    // so bumping the key drops v1's stale entries (collections merely opened).
    private let key = "recent_collections_v2"
    private let maxEntries = 10
    private let defaults: UserDefaults

    /// Most recently opened first.
    private(set) var collections: [RecentCollection] = []

    /// Injectable for tests.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func record(_ collection: RecentCollection) {
        collections.removeAll { $0.id == collection.id }
        collections.insert(collection, at: 0)
        if collections.count > maxEntries {
            collections = Array(collections.prefix(maxEntries))
        }
        save()
    }

    func recent(limit: Int = 8) -> [RecentCollection] {
        Array(collections.prefix(limit))
    }

    // MARK: - Persistence

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([RecentCollection].self, from: data)
        else { return }
        collections = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(collections) else { return }
        defaults.set(data, forKey: key)
    }
}
