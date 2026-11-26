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

struct RecentCollection: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    /// Square art (fallback for the shelf card).
    var squareImageURL: URL?
    /// Wide 16:9-ish art, used for the Home shelf card.
    var wideImageURL: URL?
    var numPosts: Int?
    /// The collection's creator (campaign) name. Nil for entries recorded before
    /// this field existed (they decode to nil).
    var campaignName: String?
    /// Title of the episode the collection's Play would start — a display hint
    /// for the Continue Collection card. Nil for entries recorded before this
    /// field existed (they decode to nil).
    var nextEpisodeTitle: String?
    /// ID of the episode Play would start. Used to tell a genuinely new target
    /// apart from the same one rendered again.
    var nextEpisodeID: String? = nil
    /// Playable episodes the collection had the last time it was synced or the
    /// viewer opened it. The baseline for `newEpisodeCount`.
    var episodeCount: Int? = nil
    /// Playable episodes added since the viewer last opened the collection.
    /// Nil or zero hides the "N new" badge.
    var newEpisodeCount: Int? = nil
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

    func recentEntry(id: String) -> RecentCollection? {
        collections.first { $0.id == id }
    }

    /// Collections removed permanently. `record` and `update` ignore them.
    func isHidden(id: String) -> Bool {
        hiddenIDs.contains(id)
    }

    /// Updates an existing entry in place. `promote` moves it to the front,
    /// which is reserved for "this collection got new episodes" so a plain
    /// metadata refresh doesn't reshuffle the shelf.
    func update(_ collection: RecentCollection, promote: Bool = false) {
        guard !hiddenIDs.contains(collection.id),
              let index = collections.firstIndex(where: { $0.id == collection.id })
        else { return }

        if !promote, collections[index] == collection { return }

        collections[index] = collection
        if promote {
            collections.remove(at: index)
            collections.insert(collection, at: 0)
        }
        save()
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
