//
//  PostActionsMenu.swift
//  PatreonTV
//
//  Press-and-hold menu on a post/episode card: mark it watched or unwatched.
//  On tvOS the context menu opens with a long press (press-and-hold the select
//  button) on the focused card.
//
//  The items are contextual, evaluated when the menu opens:
//  - not started  → "Mark as Watched"
//  - in progress  → both
//  - finished     → "Mark as Unwatched"
//
//  CollectionView also passes `onSelect`, which adds the entry point to multi-
//  selection mode.
//

import SwiftUI

extension View {
    /// Adds the watched/unwatched context menu for the given post. Only offered
    /// for playable content (video/audio); polls, text, images and links never
    /// accumulate watch progress.
    ///
    /// - Parameter onSelect: When non-nil, adds a "Select Episodes" action that
    ///   enters multi-selection mode. Only used by CollectionView.
    func postActionsMenu(post: Post, onSelect: (() -> Void)? = nil) -> some View {
        modifier(PostActionsMenu(
            postID: post.id,
            isPlayable: UpNextResolver.isPlayable(post),
            onSelect: onSelect
        ))
    }
}

private struct PostActionsMenu: ViewModifier {

    let postID: String
    let isPlayable: Bool
    let onSelect: (() -> Void)?

    func body(content: Content) -> some View {
        Group {
            if isPlayable {
                content.contextMenu {
                    let finished = PlaybackProgressStore.shared.progress(for: postID)?.isFinished == true
                    let started = PlaybackProgressStore.shared.progress(for: postID) != nil && !finished

                    if !finished {
                        Button {
                            PlaybackProgressStore.shared.markWatched(postID: postID)
                        } label: {
                            Label("Mark as Watched", systemImage: "checkmark.circle")
                        }
                    }

                    if started || finished {
                        Button {
                            PlaybackProgressStore.shared.markUnwatched(postID: postID)
                        } label: {
                            Label("Mark as Unwatched", systemImage: "arrow.uturn.backward.circle")
                        }
                    }

                    if let onSelect {
                        Divider()

                        Button(action: onSelect) {
                            Label("Select Episodes", systemImage: "checklist")
                        }
                    }
                }
            } else {
                content
            }
        }
    }
}
