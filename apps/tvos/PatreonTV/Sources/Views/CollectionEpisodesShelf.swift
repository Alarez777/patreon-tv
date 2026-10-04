//
//  CollectionEpisodesShelf.swift
//  PatreonTV
//
//  A horizontal strip of a collection's episodes, shown on a post's detail so
//  the viewer can jump between chapters. Oldest is on the left, newest on the
//  right, and it scrolls to the current episode on appear.
//

import NukeUI
import Observation
import SwiftUI

struct CollectionEpisodesShelf: View {

    let title: String
    let collectionID: String
    let currentPostID: String
    /// Opens an episode with autoplay (remote Play button). Nil leaves the
    /// normal select behaviour.
    var onPlay: ((String) -> Void)? = nil

    @State private var vm = CollectionEpisodesViewModel()

    /// Trailing space so even the last episode can scroll to the leading edge.
    private let trailingFiller: CGFloat = 1800

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(PatreonColors.primaryText)
                .lineLimit(1)
                .padding(.horizontal, 60)
                .accessibilityAddTraits(.isHeader)

            if !vm.posts.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 24) {
                            ForEach(vm.posts) { post in
                                NavigationLink(value: DeepLinkDestination.post(id: post.id, autoplay: false)) {
                                    EpisodeCard(post: post, isCurrent: post.id == currentPostID)
                                }
                                .buttonStyle(.card)
                                .onPlayPauseCommand { onPlay?(post.id) }
                                .id(post.id)
                            }

                            Color.clear.frame(width: trailingFiller)
                        }
                        .padding(.leading, 60)
                        .padding(.vertical, 30)
                    }
                    .scrollClipDisabled()
                    // Current episode at the leading edge; newer ones sit to
                    // the right.
                    .onAppear { proxy.scrollTo(currentPostID, anchor: .leading) }
                }
            }
        }
        .focusSection()
        .task { await vm.load(collectionID: collectionID) }
    }
}

private struct EpisodeCard: View {

    let post: Post
    let isCurrent: Bool

    private let cardWidth: CGFloat = 340
    private let cardHeight: CGFloat = 191   // 16:9

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            thumbnail
                .frame(width: cardWidth, height: cardHeight)
                .background(PatreonColors.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    if isCurrent {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(PatreonColors.brand, lineWidth: 4)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if isCurrent {
                        Text("NOW PLAYING")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(PatreonColors.brand, in: Capsule())
                            .foregroundStyle(.white)
                            .padding(10)
                    }
                }

            Text(post.attributes.title ?? "Episode")
                .font(.callout)
                .foregroundStyle(PatreonColors.primaryText)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: cardWidth, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(post.attributes.title ?? "Episode")
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let url = post.attributes.posterImageURL {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    PatreonColors.cardSurface
                }
            }
        } else {
            PatreonColors.cardSurface
        }
    }
}

// MARK: - View model

@MainActor
@Observable
final class CollectionEpisodesViewModel {

    var posts: [Post] = []

    func load(collectionID: String) async {
        if let cached = CollectionPostsCache.shared.posts(for: collectionID), !cached.isEmpty {
            posts = Self.oldestFirst(cached)
            return
        }
        do {
            let doc = try await PatreonClient.shared.collection(id: collectionID)
            let ordered = doc.data.orderedPosts(from: doc.included ?? [])
            CollectionPostsCache.shared.store(ordered, for: collectionID)
            posts = Self.oldestFirst(ordered)
        } catch {
            posts = []
        }
    }

    /// The strip reads left→right oldest→newest, so the newest episodes sit to
    /// the right.
    private static func oldestFirst(_ posts: [Post]) -> [Post] {
        Array(posts.reversed())
    }
}
