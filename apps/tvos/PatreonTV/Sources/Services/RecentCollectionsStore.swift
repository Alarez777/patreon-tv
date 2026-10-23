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
    /// The collection's creator (campaign) name. Nil for entries recorded before
    /// this field existed (they decode to nil).
    let campaignName: String?
    /// Title of the episode the collection's Play would start — a display hint
    /// for the Continue Collection card. Nil for entries recorded before this
    /// field existed (they decode to nil).
    let nextEpisodeTitle: String?
}

@MainActor
@Observable
final class RecentCollectionsStore {

    static let shared = RecentCollectionsStore()

    // v2: collections are only recorded once something in them has been watched,
    // so bumping the key drops v1's stale entries (collections merely opened).
    private let key = "recent_collections_v2"
    private let hiddenKey = "hidden_collection_ids_v1"
    private let maxEntries = 10
    private let defaults: UserDefaults

    /// Most recently opened first.
    private(set) var collections: [RecentCollection] = []

    /// Collections removed permanently. `record` ignores them until the user
    /// adds them back from a collection card.
    private var hiddenIDs: Set<String> = []

    /// Injectable for tests.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func record(_ collection: RecentCollection) {
        guard !hiddenIDs.contains(collection.id) else { return }
        insert(collection)
    }

    /// Adds a collection manually and clears a previous permanent hide.
    func add(_ collection: RecentCollection) {
        hiddenIDs.remove(collection.id)
        saveHidden()
        insert(collection)
    }

    /// Temporary removal: watching something in the collection adds it again.
    func remove(id: String) {
        collections.removeAll { $0.id == id }
        save()
    }

    /// Permanent removal: `record` won't bring it back until `add` is called.
    func hide(id: String) {
        collections.removeAll { $0.id == id }
        hiddenIDs.insert(id)
        save()
        saveHidden()
    }

    func isTracked(id: String) -> Bool {
        collections.contains { $0.id == id }
    }

    func recent(limit: Int = 8) -> [RecentCollection] {
        Array(collections.prefix(limit))
    }

    /// Wipes Continue Collection history, including permanently hidden entries.
    func clearAll() {
        collections.removeAll()
        hiddenIDs.removeAll()
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: hiddenKey)
    }

    private func insert(_ collection: RecentCollection) {
        collections.removeAll { $0.id == collection.id }
        collections.insert(collection, at: 0)
        if collections.count > maxEntries {
            collections = Array(collections.prefix(maxEntries))
        }
        save()
    }

    // MARK: - Persistence

    private func load() {
        hiddenIDs = Set(defaults.stringArray(forKey: hiddenKey) ?? [])

        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([RecentCollection].self, from: data)
        else { return }
        collections = decoded.filter { !hiddenIDs.contains($0.id) }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(collections) else { return }
        defaults.set(data, forKey: key)
    }

    private func saveHidden() {
        defaults.set(Array(hiddenIDs), forKey: hiddenKey)
    }
}
