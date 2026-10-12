//
//  CollectionPlaybackResolver.swift
//  PatreonTV
//
//  Resolves which episode to play when the viewer hits Play on a collection
//  card: the last episode they watched if it's unfinished, otherwise the next
//  one (oldest→newest), or the first episode when nothing's been watched.
//  Flags when a finished collection should restart from the beginning, so the
//  caller can confirm first.
//
//  The same "remote Play" affordance is exposed here for collection cards
//  (Continue Collection and a creator's collection list).
//

import SwiftUI
import os.log

@MainActor
enum CollectionPlaybackResolver {

    struct Target {
        let postID: String
        /// Episode title, used for the Continue Collection hint.
        let title: String
        /// True when the whole collection is finished and we should restart from
        /// episode 1 (the caller should confirm first).
        let isRestart: Bool
    }

    private static let log = Logger(subsystem: "com.patreontv.PatreonTV", category: "CollectionPlay")

    /// Next episode to play for a collection, or nil when it has no playable posts.
    static func resolve(collectionID: String) async -> Target? {
        target(in: await collectionPosts(collectionID: collectionID))
    }

    /// Pure selection core: given a collection's posts (in `post_ids` order,
    /// newest-first), pick the next episode to play.
    static func target(in posts: [Post]) -> Target? {
        let ordered = posts.reversed().filter { UpNextResolver.isPlayable($0) }   // oldest→newest
        guard let first = ordered.first else { return nil }

        guard let recent = PlaybackProgressStore.shared.mostRecent(in: ordered.map(\.id)),
              let index = ordered.firstIndex(where: { $0.id == recent.postID })
        else {
            log.info("Collection: nothing watched, starting at \(first.id)")
            return make(first, isRestart: false)
        }
        if !recent.isFinished {
            return make(ordered[index], isRestart: false)
        }
        if let next = ordered.dropFirst(index + 1).first {
            log.info("Collection: finished \(recent.postID), next \(next.id)")
            return make(next, isRestart: false)
        }
        log.info("Collection: finished last episode, restarting at \(first.id)")
        return make(first, isRestart: true)
    }

    private static func make(_ post: Post, isRestart: Bool) -> Target {
        Target(postID: post.id, title: post.attributes.title ?? "Untitled", isRestart: isRestart)
    }

    /// A collection's posts in `post_ids` order, from the cache or a fetch.
    private static func collectionPosts(collectionID: String) async -> [Post] {
        if let cached = CollectionPostsCache.shared.posts(for: collectionID), !cached.isEmpty {
            return cached
        }
        guard let doc = try? await PatreonClient.shared.collection(id: collectionID) else {
            return []
        }
        let ordered = doc.data.orderedPosts(from: doc.included ?? [])
        CollectionPostsCache.shared.store(
            collection: doc.data,
            posts: ordered,
            campaignName: (doc.included ?? []).firstCampaignName
        )
        return ordered
    }
}

// MARK: - Remote Play affordance

/// Gives a collection card the same "Play starts the collection" behavior the
/// post cards have: the remote Play/Pause button resolves the target episode
/// and jumps straight into playback, asking for confirmation when it would
/// restart a finished collection.
private struct CollectionPlayModifier: ViewModifier {

    let collectionID: String
    /// Starts playback for a resolved episode. Args: collection, post.
    let onPlay: ((String, String) -> Void)?

    @State private var pendingRestartPostID: String?

    func body(content: Content) -> some View {
        content
            .onPlayPauseCommand {
                Task { await play() }
            }
            .alert(
                "Restart collection?",
                isPresented: Binding(
                    get: { pendingRestartPostID != nil },
                    set: { if !$0 { pendingRestartPostID = nil } }
                )
            ) {
                Button("Restart") {
                    if let postID = pendingRestartPostID { onPlay?(collectionID, postID) }
                    pendingRestartPostID = nil
                }
                Button("Cancel", role: .cancel) { pendingRestartPostID = nil }
            } message: {
                Text("You already finished this collection. Restart from the first episode?")
            }
    }

    private func play() async {
        guard let onPlay,
              let target = await CollectionPlaybackResolver.resolve(collectionID: collectionID)
        else { return }
        if target.isRestart {
            pendingRestartPostID = target.postID
        } else {
            onPlay(collectionID, target.postID)
        }
    }
}

extension View {
    func collectionPlay(collectionID: String, onPlay: ((String, String) -> Void)?) -> some View {
        modifier(CollectionPlayModifier(collectionID: collectionID, onPlay: onPlay))
    }
}
