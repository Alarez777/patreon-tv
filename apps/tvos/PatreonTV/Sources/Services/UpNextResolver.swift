//
//  UpNextResolver.swift
//  PatreonTV
//
//  Picks the post to queue after playback finishes: the next playable post
//  from the same creator, in the campaign feed's newest-first order (so
//  "next" walks backward through the catalog, the direction a viewer browsing
//  from the top of a feed naturally moves). Prefers posts the user hasn't
//  finished; falls back to the immediate neighbor if everything's watched.
//

import Foundation
import os.log

enum UpNextResolver {

    private static let log = Logger(subsystem: "com.patreontv.PatreonTV", category: "UpNext")

    /// Post types we can actually hand to a player.
    nonisolated static let playableTypes: Set<Post.PostType> = [
        .videoExternalFile, .videoEmbed, .audioFile, .audioEmbed, .podcast,
    ]

    nonisolated static func isPlayable(_ post: Post) -> Bool {
        guard post.attributes.currentUserCanView != false else { return false }
        guard let type = post.attributes.postType else { return false }
        return playableTypes.contains(type)
    }

    /// Pure selection core (unit-tested): given the campaign's posts in feed
    /// order (newest first), return the next playable post after `currentID`,
    /// preferring one the user hasn't finished.
    nonisolated static func selectNext(
        afterPostID currentID: String,
        in posts: [Post],
        isFinished: (String) -> Bool
    ) -> Post? {
        guard let index = posts.firstIndex(where: { $0.id == currentID }) else { return nil }
        let candidates = posts[(index + 1)...].filter { isPlayable($0) }
        return candidates.first { !isFinished($0.id) } ?? candidates.first
    }

    /// Ordered IDs to the right of `currentID` in a shelf's display order,
    /// skipping posts the viewer already finished. The caller fetches each one
    /// and stops at the first playable card, so a shelf of text/image posts
    /// doesn't produce a non-playable suggestion. Nil-equivalent (empty) at the
    /// end of the shelf — deliberately no fallback to the creator's feed.
    ///
    /// `limit` bounds the number of fetches when a long run of neighbors is
    /// unplayable, so Up Next can't turn into a request storm.
    nonisolated static func candidatesAfter(
        _ currentID: String,
        in queue: [String],
        isFinished: (String) -> Bool,
        limit: Int = 10
    ) -> [String] {
        guard let index = queue.firstIndex(of: currentID) else { return [] }
        var candidates: [String] = []
        for id in queue[(index + 1)...] where !isFinished(id) {
            candidates.append(id)
            if candidates.count == limit { break }
        }
        return candidates
    }

    /// Fetches the campaign feed (following the cursor a bounded number of
    /// pages until the current post is located) and picks the next post.
    /// Returns nil on any failure — Up Next is best-effort.
    @MainActor
    static func next(after currentPostID: String, campaignID: String) async -> Post? {
        var cursor: String?
        var posts: [Post] = []

        for _ in 0..<3 {
            guard let page = try? await PatreonClient.shared.campaignPosts(
                campaignID: campaignID, cursor: cursor, limit: 30
            ) else { break }
            posts.append(contentsOf: page.data)

            // Stop once we can see past the current post.
            if let index = posts.firstIndex(where: { $0.id == currentPostID }),
               index < posts.count - 1 {
                break
            }
            guard let nextCursor = page.nextCursor else { break }
            cursor = nextCursor
        }

        let next = selectNext(afterPostID: currentPostID, in: posts) {
            PlaybackProgressStore.shared.progress(for: $0)?.isFinished == true
        }
        if let next {
            log.info("Up next after \(currentPostID): \(next.id)")
        } else {
            log.info("No up-next candidate after \(currentPostID)")
        }
        return next
    }
}
