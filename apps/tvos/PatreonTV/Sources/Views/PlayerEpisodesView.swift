//
//  PlayerEpisodesView.swift
//  PatreonTV
//
//  Content for the player's "Episodes" info tab: the collection's episodes as a
//  horizontal carousel, focused on the one playing and scrolled so it sits in
//  the middle.
//

import SwiftUI

struct PlayerEpisodesView: View {

    let episodes: [Post]
    let currentPostID: String
    let onSelect: (String) -> Void

    @FocusState private var focusedID: String?

    /// Oldest on the left, newest on the right.
    private var ordered: [Post] { Array(episodes.reversed()) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 24) {
                    ForEach(ordered) { post in
                        Button {
                            onSelect(post.id)
                        } label: {
                            EpisodeCard(post: post, isCurrent: post.id == currentPostID)
                        }
                        .buttonStyle(.card)
                        .focused($focusedID, equals: post.id)
                        .id(post.id)
                    }

                    // Trailing space so even the last episode can sit at the
                    // leading edge.
                    Color.clear.frame(width: 1600)
                }
                .padding(.leading, 60)
                .padding(.vertical, 24)
            }
            .scrollClipDisabled()
            .onAppear {
                // The carousel is lazy, so the current episode's card isn't
                // realized instantly. Scroll it to the leading edge, then move
                // focus once it exists.
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(300))
                    proxy.scrollTo(currentPostID, anchor: .leading)
                    try? await Task.sleep(for: .milliseconds(300))
                    focusedID = currentPostID
                }
            }
        }
    }
}
