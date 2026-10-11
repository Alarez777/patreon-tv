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
        /// True when the whole collection is finished and we should restart from
        /// episode 1 (the caller should confirm first).
        let isRestart: Bool
    }

    private static let log = Logger(subsystem: "com.patreontv.PatreonTV", category: "CollectionPlay")

    /// Next episode to play for a collection, or nil when it has no playable posts.
    static func resolve(collectionID: String) async -> Target? {
        let posts = await orderedPosts(collectionID: collectionID)
            .filter { UpNextResolver.isPlayable($0) }
        guard let first = posts.first else { return nil }

        guard let recent = PlaybackProgressStore.shared.mostRecent(in: posts.map(\.id)) else {
            log.info("Collection \(collectionID): nothing watched, starting at \(first.id)")
            return Target(postID: first.id, isRestart: false)
        }
        if !recent.isFinished {
            log.info("Collection \(collectionID): resuming unfinished \(recent.postID)")
            return Target(postID: recent.postID, isRestart: false)
        }
        guard let index = posts.firstIndex(where: { $0.id == recent.postID }) else {
            return Target(postID: first.id, isRestart: false)
        }
        if let next = posts.dropFirst(index + 1).first {
            log.info("Collection \(collectionID): finished \(recent.postID), next \(next.id)")
            return Target(postID: next.id, isRestart: false)
        }
        log.info("Collection \(collectionID): finished last episode, restarting at \(first.id)")
        return Target(postID: first.id, isRestart: true)
    }

    /// A collection's posts in oldest→newest order, from the cache or a fetch.
    private static func orderedPosts(collectionID: String) async -> [Post] {
        if let cached = CollectionPostsCache.shared.posts(for: collectionID), !cached.isEmpty {
            return Array(cached.reversed())
        }
        guard let doc = try? await PatreonClient.shared.collection(id: collectionID) else {
            return []
        }
        let ordered = doc.data.orderedPosts(from: doc.included ?? [])
        CollectionPostsCache.shared.store(collection: doc.data, posts: ordered)
        return Array(ordered.reversed())
    }
}

// MARK: - Remote Play affordance

/// Gives a collection card the same "Play starts the collection" behavior the
/// post cards have: the remote Play/Pause button resolves the target episode
/// and jumps straight into playback, asking for confirmation when it would
/// restart a finished collection.
private struct CollectionPlayModifier: ViewModifier {

    let collectionID: String
    let onPlayPost: ((String, String?) -> Void)?

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
                    if let postID = pendingRestartPostID { onPlayPost?(postID, collectionID) }
                    pendingRestartPostID = nil
                }
                Button("Cancel", role: .cancel) { pendingRestartPostID = nil }
            } message: {
                Text("You already finished this collection. Restart from the first episode?")
            }
    }

    private func play() async {
        guard let onPlayPost,
              let target = await CollectionPlaybackResolver.resolve(collectionID: collectionID)
        else { return }
        if target.isRestart {
            pendingRestartPostID = target.postID
        } else {
            onPlayPost(target.postID, collectionID)
        }
    }
}

extension View {
    func collectionPlay(collectionID: String, onPlayPost: ((String, String?) -> Void)?) -> some View {
        modifier(CollectionPlayModifier(collectionID: collectionID, onPlayPost: onPlayPost))
    }
}
