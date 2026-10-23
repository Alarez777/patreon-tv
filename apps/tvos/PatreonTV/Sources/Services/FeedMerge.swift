//
//  FeedMerge.swift
//  PatreonTV
//
//  Pure merge of a freshly-fetched feed page into the posts already on screen.
//  New posts go to the front, changed posts are updated in place, and posts
//  that fell outside the page window (already-paginated pages) are preserved.
//

import Foundation

enum FeedMerge {

    struct Outcome {
        let posts: [Post]
        /// IDs present in `incoming` that weren't in `existing`, in page order.
        let addedIDs: [String]
        /// An existing post's card-facing attributes changed.
        let updated: Bool

        var changed: Bool { !addedIDs.isEmpty || updated }
    }

    /// Merge `incoming` (newest first) into `existing` (newest first).
    /// Returns `changed == false` when the page added or modified nothing, so
    /// callers can skip assigning state and avoid a needless re-render.
    nonisolated static func merge(existing: [Post], incoming: [Post]) -> Outcome {
        guard !incoming.isEmpty else {
            return Outcome(posts: existing, addedIDs: [], updated: false)
        }

        var byID = Dictionary(
            existing.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var addedIDs: [String] = []
        var updated = false

        for post in incoming {
            if let current = byID[post.id] {
                // Attributes carry everything a card renders (title, teaser,
                // poster, visibility). Relationships can differ between feed
                // endpoints without the post actually changing, so ignore them.
                if current.attributes != post.attributes {
                    byID[post.id] = post
                    updated = true
                }
            } else {
                byID[post.id] = post
                addedIDs.append(post.id)
            }
        }

        let posts = byID.values.sorted(by: isNewer)
        return Outcome(posts: posts, addedIDs: addedIDs, updated: updated)
    }

    /// Newest first, ties broken by id so the order is deterministic (Swift's
    /// sort isn't guaranteed stable). Missing dates sink to the bottom.
    nonisolated static func isNewer(_ a: Post, _ b: Post) -> Bool {
        let aDate = a.attributes.publishedAt ?? ""
        let bDate = b.attributes.publishedAt ?? ""
        if aDate != bDate { return aDate > bDate }
        return a.id > b.id
    }
}
