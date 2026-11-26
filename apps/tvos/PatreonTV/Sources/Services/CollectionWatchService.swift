//
//  CollectionWatchService.swift
//  PatreonTV
//
//  Bulk "mark collection as watched/unwatched" used by the collection card
//  context menu. Watch state is per post, so a collection is resolved to its
//  playable posts and every episode is updated through PlaybackProgressStore.
//
//  Collections are fetched whole from `/api/collection/{id}`. A recent cache
//  snapshot avoids that request; if the network fails, the last snapshot is
//  used as a best-effort fallback.
//

import Foundation
import os.log

@MainActor
enum CollectionWatchService {

    private static let log = Logger(subsystem: "com.patreontv.PatreonTV", category: "CollectionWatch")

    /// Marks every playable episode in a collection. Returns the number of
    /// posts affected, or nil when the collection couldn't be loaded at all.
    @discardableResult
    static func markAll(watched: Bool, collectionID: String) async -> Int? {
        guard let loaded = await loadPosts(for: collectionID) else { return nil }

        let playableCount = playableIDs(in: loaded.posts).count
        let affected = apply(watched: watched, posts: loaded.posts)
        guard affected > 0 else { return 0 }

        // Marking the whole collection watched also acknowledges its "new
        // episodes" badge. Skip this when we're working from a stale fallback
        // snapshot: episodes added since that snapshot aren't marked, and
        // clearing the badge would hide them.
        if watched, loaded.isFresh {
            acknowledgeNewEpisodes(
                collectionID: collectionID,
                playableCount: playableCount
            )
        }

        return affected
    }

    /// Marks only the posts selected in the collection's selection mode.
    /// `posts` must preserve the collection's newest-first order.
    @discardableResult
    static func markSelected(watched: Bool, posts: [Post]) -> Int {
        apply(watched: watched, posts: posts)
    }

    /// Clears the Continue Collection "new episodes" badge and advances the
    /// baseline. Used when a watched action covers every playable episode.
    static func acknowledgeNewEpisodes(collectionID: String, playableCount: Int) {
        guard let entry = RecentCollectionsStore.shared.recentEntry(id: collectionID) else { return }
        RecentCollectionsStore.shared.update(
            markedSeen(entry, playableCount: playableCount)
        )
    }

    private static func apply(watched: Bool, posts: [Post]) -> Int {
        // Watched only touches posts that can actually carry progress. The
        // unwatched direction also clears stale records for locked or removed
        // episodes, so it covers every post in the given set.
        let ids = watched ? playableIDs(in: posts) : uniqueIDs(in: posts)
        guard !ids.isEmpty else { return 0 }

        if watched {
            PlaybackProgressStore.shared.markWatched(postIDs: ids)
        } else {
            PlaybackProgressStore.shared.markUnwatched(postIDs: ids)
        }

        // Other tracked collections can share episodes with this one.
        ContinueCollectionSync.shared.refreshTargetsFromCache()
        return ids.count
    }

    /// Oldest-first playable IDs, de-duplicated. Marking in this order leaves
    /// the newest episode as the most recently watched, so Play on a finished
    /// collection offers to restart from the first episode.
    nonisolated static func playableIDs(in posts: [Post]) -> [String] {
        var seen = Set<String>()
        return posts.reversed().compactMap { post in
            guard UpNextResolver.isPlayable(post),
                  seen.insert(post.id).inserted
            else { return nil }
            return post.id
        }
    }

    /// Every post ID in the collection, de-duplicated.
    nonisolated static func uniqueIDs(in posts: [Post]) -> [String] {
        var seen = Set<String>()
        return posts.compactMap { post in
            seen.insert(post.id).inserted ? post.id : nil
        }
    }

    /// Clears the Continue Collection "new episodes" badge and advances the
    /// baseline, matching what opening the collection does.
    static func markedSeen(
        _ entry: RecentCollection,
        playableCount: Int
    ) -> RecentCollection {
        var updated = entry
        updated.episodeCount = playableCount
        updated.newEpisodeCount = 0
        return updated
    }

    // MARK: - Loading

    private struct LoadedCollection {
        let posts: [Post]
        /// False when this is a stale cache fallback after a failed fetch.
        let isFresh: Bool
    }

    private static func loadPosts(for collectionID: String) async -> LoadedCollection? {
        let cached = CollectionPostsCache.shared.snapshot(for: collectionID)
        if let cached,
           !cached.posts.isEmpty,
           Date().timeIntervalSince(cached.fetchedAt) < ContentRefresh.pageMinInterval {
            return LoadedCollection(posts: cached.posts, isFresh: true)
        }

        do {
            let doc = try await PatreonClient.shared.collection(
                id: collectionID,
                cachePolicy: .reloadIgnoringLocalCacheData
            )
            let posts = doc.data.orderedPosts(from: doc.included ?? [])
            CollectionPostsCache.shared.store(
                collection: doc.data,
                posts: posts,
                campaignName: (doc.included ?? []).firstCampaignName
            )
            return LoadedCollection(posts: posts, isFresh: true)
        } catch {
            log.error(
                "Collection watch update failed to load \(collectionID): \(String(describing: error))"
            )
            guard let cached else { return nil }
            return LoadedCollection(posts: cached.posts, isFresh: false)
        }
    }
}
