//
//  ContinueCollectionSync.swift
//  PatreonTV
//
//  Keeps the "Continue Collection" shelf honest without polling every saved
//  collection on every Home refresh. New feed posts carry their collection
//  linkage (when Patreon returns it), so only the saved collections that got a
//  new episode are fetched. A coarse sweep covers collection edits that never
//  produce a new post.
//

import Foundation
import os.log

@MainActor
final class ContinueCollectionSync {

    static let shared = ContinueCollectionSync()

    /// Fallback sweep. Targeted refreshes from the feed are immediate; this
    /// only catches a collection Patreon reordered/edited without publishing a
    /// new post. Kept deliberately slow to avoid request storms.
    static let sweepInterval: TimeInterval = 30 * 60

    private static let log = Logger(subsystem: "com.patreontv.PatreonTV", category: "ContinueCollection")

    private var isRefreshing = false
    private var pendingIDs: Set<String> = []

    private struct RefreshResult: Sendable {
        let id: String
        let collection: PatreonCollection
        let campaignName: String?
        let targetPostID: String?
        let targetTitle: String?
        let targetPublishedAt: String?
        let playableCount: Int
    }

    /// Refreshes saved collections whose cached snapshot is older than
    /// `minInterval`. On launch the cache is empty, so this seeds every card.
    func refreshTrackedIfStale(minInterval: TimeInterval = sweepInterval) async {
        guard ContentPreferences.shared.showContinueCollection else { return }

        let now = Date()
        let staleIDs = RecentCollectionsStore.shared.recent(limit: 8).compactMap { entry -> String? in
            guard let snapshot = CollectionPostsCache.shared.snapshot(for: entry.id) else {
                return entry.id
            }
            return now.timeIntervalSince(snapshot.fetchedAt) >= minInterval ? entry.id : nil
        }
        guard !staleIDs.isEmpty else {
            refreshTargetsFromCache()
            return
        }
        await refresh(ids: Set(staleIDs))
    }

    /// Uses the collection linkage on newly-added feed posts to refresh only
    /// the saved collections they belong to. `membership` carries the
    /// post → collection mapping derived from the feed's included collections,
    /// which covers responses where the relationship linkage is missing.
    /// Returns the number of saved collections refreshed (0 when none of the
    /// new posts touch the shelf).
    @discardableResult
    func noteNewPosts(
        _ posts: [Post],
        membership: [String: Set<String>] = [:]
    ) async -> Int {
        guard ContentPreferences.shared.showContinueCollection else { return 0 }

        let tracked = Set(RecentCollectionsStore.shared.recent(limit: 8).map(\.id))
        guard !tracked.isEmpty else { return 0 }

        let affected = Set(posts.flatMap { post in
            Set(post.collectionIDs).union(membership[post.id] ?? [])
        }).intersection(tracked)
        guard !affected.isEmpty else { return 0 }

        await refresh(ids: affected)
        return affected.count
    }

    /// Maps collection `post_ids` to collection IDs, so a post can be matched
    /// to its collection even when the feed omits the relationship linkage.
    nonisolated static func membership(from collections: [PatreonCollection]) -> [String: Set<String>] {
        var out: [String: Set<String>] = [:]
        for collection in collections {
            guard let postIDs = collection.attributes.postIDs else { continue }
            for postID in postIDs {
                out[String(postID), default: []].insert(collection.id)
            }
        }
        return out
    }

    /// Recomputes the "next episode" from the in-memory snapshots, with no
    /// network. Called when playback progress changes so a finished episode
    /// immediately advances the card.
    func refreshTargetsFromCache() {
        guard ContentPreferences.shared.showContinueCollection else { return }

        for entry in RecentCollectionsStore.shared.recent(limit: 8) {
            guard let posts = CollectionPostsCache.shared.posts(for: entry.id),
                  let target = CollectionPlaybackResolver.target(in: posts),
                  entry.nextEpisodeID != target.postID || entry.nextEpisodeTitle != target.title
            else { continue }

            var updated = entry
            updated.nextEpisodeTitle = target.title
            updated.nextEpisodeID = target.postID
            RecentCollectionsStore.shared.update(updated)
        }
    }

    // MARK: - Fetch + apply

    /// Coalesces overlapping callers: an in-flight batch finishes, then any
    /// IDs requested meanwhile run as the next batch instead of being dropped.
    private func refresh(ids: Set<String>) async {
        pendingIDs.formUnion(ids)
        guard !isRefreshing else { return }

        isRefreshing = true
        defer { isRefreshing = false }

        while !pendingIDs.isEmpty {
            let batch = pendingIDs
            pendingIDs.removeAll()
            await refreshBatch(batch)
        }
    }

    private func refreshBatch(_ ids: Set<String>) async {
        let entries = Dictionary(
            uniqueKeysWithValues: RecentCollectionsStore.shared.recent(limit: 8).map { ($0.id, $0) }
        )
        let knownIDs = ids.filter { entries[$0] != nil }
        guard !knownIDs.isEmpty else { return }

        let results = await withTaskGroup(of: RefreshResult?.self) { group in
            for id in knownIDs {
                group.addTask { await Self.fetch(id: id) }
            }
            var out: [RefreshResult] = []
            for await result in group {
                if let result { out.append(result) }
            }
            return out
        }

        apply(results)
    }

    private static func fetch(id: String) async -> RefreshResult? {
        do {
            let doc = try await PatreonClient.shared.collection(
                id: id,
                cachePolicy: .reloadIgnoringLocalCacheData
            )
            let posts = doc.data.orderedPosts(from: doc.included ?? [])
            let campaignName = (doc.included ?? []).firstCampaignName
            let target = CollectionPlaybackResolver.target(in: posts)
            let playableCount = posts.filter(UpNextResolver.isPlayable).count
            let targetPublishedAt = posts.first { $0.id == target?.postID }?.attributes.publishedAt

            CollectionPostsCache.shared.store(
                collection: doc.data,
                posts: posts,
                campaignName: campaignName,
                fetchedAt: Date()
            )

            return RefreshResult(
                id: id,
                collection: doc.data,
                campaignName: campaignName,
                targetPostID: target?.postID,
                targetTitle: target?.title,
                targetPublishedAt: targetPublishedAt,
                playableCount: playableCount
            )
        } catch {
            // Best-effort: a failed refresh leaves the last good card in place.
            log.error("Refresh failed for \(id): \(String(describing: error))")
            return nil
        }
    }

    /// Pure badge calculation, extracted so the "new episodes" rule is
    /// testable: only playable episodes count, and the badge never exceeds the
    /// collection's current episode count.
    nonisolated static func badge(
        existingCount: Int?,
        existingBadge: Int?,
        newPlayableCount: Int
    ) -> Int {
        let baseline = existingCount ?? newPlayableCount
        let delta = max(0, newPlayableCount - baseline)
        return min((existingBadge ?? 0) + delta, newPlayableCount)
    }

    private func apply(_ results: [RefreshResult]) {
        var promoted: [(entry: RecentCollection, publishedAt: String)] = []

        for result in results {
            guard let old = RecentCollectionsStore.shared.recentEntry(id: result.id) else { continue }

            // Compare playable episodes, not raw post counts: a new text post
            // shouldn't produce a "new episode" badge.
            let baseline = old.episodeCount ?? result.playableCount
            let delta = max(0, result.playableCount - baseline)
            let badge = Self.badge(
                existingCount: old.episodeCount,
                existingBadge: old.newEpisodeCount,
                newPlayableCount: result.playableCount
            )

            var updated = old
            updated.title = result.collection.attributes.title ?? old.title
            updated.squareImageURL = result.collection.attributes.thumbnail?.bestImageURL ?? old.squareImageURL
            updated.wideImageURL = result.collection.attributes.thumbnail?.wideImageURL ?? old.wideImageURL
            updated.numPosts = result.collection.attributes.numPosts ?? old.numPosts
            updated.campaignName = result.campaignName ?? old.campaignName
            updated.nextEpisodeTitle = result.targetTitle ?? old.nextEpisodeTitle
            updated.nextEpisodeID = result.targetPostID ?? old.nextEpisodeID
            updated.episodeCount = result.playableCount
            updated.newEpisodeCount = badge

            if delta > 0 {
                promoted.append((updated, result.targetPublishedAt ?? ""))
            } else {
                RecentCollectionsStore.shared.update(updated)
            }
        }

        // Oldest new episode first, so the newest ends up at the front.
        for item in promoted.sorted(by: { lhs, rhs in
            if lhs.publishedAt != rhs.publishedAt { return lhs.publishedAt < rhs.publishedAt }
            return lhs.entry.id < rhs.entry.id
        }) {
            RecentCollectionsStore.shared.update(item.entry, promote: true)
        }
    }
}
