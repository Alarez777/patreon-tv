//
//  CollectionEpisodesShelf.swift
//  PatreonTV
//
//  A horizontal strip of a collection's episodes, shown on a post's detail so
//  the viewer can jump between chapters. It scrolls to the current episode on
//  appear.
//

import NukeUI
import Observation
import SwiftUI

struct CollectionEpisodesShelf: View {

    let collectionID: String
    let currentPostID: String

    @State private var vm = CollectionEpisodesViewModel()

    var body: some View {
        Group {
            if !vm.posts.isEmpty {
                VStack(alignment: .leading, spacing: 24) {
                    Text("In this collection")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(PatreonColors.primaryText)
                        .padding(.horizontal, 60)
                        .accessibilityAddTraits(.isHeader)

                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 24) {
                                ForEach(vm.posts) { post in
                                    NavigationLink(value: DeepLinkDestination.post(id: post.id, autoplay: false, collectionID: collectionID)) {
                                        EpisodeCard(post: post, isCurrent: post.id == currentPostID)
                                    }
                                    .buttonStyle(.card)
                                    .id(post.id)
                                }
                            }
                            .padding(.horizontal, 60)
                            .padding(.vertical, 30)
                        }
                        .scrollClipDisabled()
                        .onAppear { proxy.scrollTo(currentPostID, anchor: .center) }
                    }
                }
                .focusSection()
            }
        }
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
        if let cached = CollectionPostsCache.shared.posts(for: collectionID) {
            posts = cached
            return
        }
        do {
            let doc = try await PatreonClient.shared.collection(id: collectionID)
            let ordered = doc.data.orderedPosts(from: doc.included ?? [])
            posts = ordered
            CollectionPostsCache.shared.store(ordered, for: collectionID)
        } catch {
            posts = []
        }
    }
}
