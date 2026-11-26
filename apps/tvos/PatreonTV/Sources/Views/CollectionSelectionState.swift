//
//  CollectionSelectionState.swift
//  PatreonTV
//
//  Selection mode for a collection's episodes. Only playable posts (video,
//  audio, podcast) can be selected; text, images, polls and links never carry
//  watch state.
//

import Foundation

struct CollectionSelectionState: Equatable {

    private(set) var isActive = false
    private(set) var postIDs: Set<String> = []
    /// Last post that received focus or was toggled. Used to restore focus when
    /// the mode ends.
    private(set) var anchorID: String?

    var count: Int { postIDs.count }
    var isEmpty: Bool { postIDs.isEmpty }

    /// Enters selection mode with the post that opened the menu selected.
    mutating func begin(with post: Post) {
        guard UpNextResolver.isPlayable(post) else { return }
        isActive = true
        postIDs = [post.id]
        anchorID = post.id
    }

    mutating func toggle(_ post: Post) {
        guard isActive, UpNextResolver.isPlayable(post) else { return }

        if postIDs.contains(post.id) {
            postIDs.remove(post.id)
        } else {
            postIDs.insert(post.id)
        }
        anchorID = post.id
    }

    mutating func selectAll(from posts: [Post]) {
        guard isActive else { return }
        postIDs = Set(posts.filter(UpNextResolver.isPlayable).map(\.id))
    }

    mutating func clear() {
        postIDs.removeAll()
    }

    /// Drops selections for posts that disappeared after a refresh.
    mutating func retain(_ validPostIDs: Set<String>) {
        postIDs.formIntersection(validPostIDs)
    }

    mutating func end() {
        isActive = false
        postIDs.removeAll()
        anchorID = nil
    }
}
