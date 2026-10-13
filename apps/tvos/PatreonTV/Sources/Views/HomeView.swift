//
//  HomeView.swift
//  PatreonTV
//
//  The couch-first landing screen: a vertical stack of horizontal shelves —
//  "New from Your Creators" first, then Continue Watching, Continue Collection,
//  and a row per creator.
//

import SwiftUI

struct HomeView: View {

    @State private var vm = HomeViewModel()
    @State private var prefs = ContentPreferences.shared

    /// Opens a post and starts playback immediately. Wired to the Siri Remote
    /// Play/Pause button on a focused card; a normal select still opens the
    /// detail screen.
    var onPlayPost: (String) -> Void = { _ in }
    /// Starts a collection's playback (remote Play on a collection card).
    /// Args: collection, post. Keeps the collection in the back stack.
    var onPlayCollection: ((String, String) -> Void)? = nil
    /// When the app opens pinned to Home, focus the leading shelf's first card
    /// instead of leaving focus on the tab bar.
    var focusFirstShelfCard: Bool = false

    /// Recently opened collections, shown under "Continue Collection" unless the
    /// user turned the shelf off in Settings.
    private var recentCollectionCards: [CollectionCardModel] {
        guard prefs.showContinueCollection else { return [] }
        return RecentCollectionsStore.shared.recent(limit: 8).map {
            CollectionCardModel(
                id: $0.id,
                title: $0.title,
                squareImageURL: $0.squareImageURL,
                wideImageURL: $0.wideImageURL,
                numPosts: $0.numPosts,
                campaignName: $0.campaignName,
                episodeTitle: $0.nextEpisodeTitle
            )
        }
    }

    /// Applies the mature-content gate to a shelf's posts based on each post's
    /// owning campaign. Keeps posts whose campaign is unknown (assumed safe).
    private func visible(_ posts: [Post]) -> [Post] {
        if prefs.showMatureContent { return posts }
        return posts.filter { vm.campaign(for: $0)?.attributes.isNSFW != true }
    }

    var body: some View {
        // No NavigationStack here — HomeShell already wraps the Home tab in one.
        // Nesting a second NavigationStack trapped upward focus so the tab bar
        // became unreachable once focus moved into the shelves.
        Group {
            switch vm.state {
            case .idle, .loading:
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                EmptyFeedView()
            case .loaded:
                loadedContent
            case .error(let message):
                ErrorView(message: message) { Task { await vm.reload() } }
            }
        }
        .task { await vm.load() }
        .background(PatreonColors.background.ignoresSafeArea())
    }

    @ViewBuilder
    private var loadedContent: some View {
        let continueWatching = visible(vm.continueWatching)
        let feed = visible(vm.homeFeed)

        // Plain VStack (not Lazy): tvOS won't render/focus below-the-fold
        // children of a LazyVStack. Shelves inside stay lazy via LazyHStack.
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 40) {
                // Short merged shelf of the latest posts across creators; the
                // per-creator rows below carry the depth.
                if !feed.isEmpty {
                    Shelf(
                        title: "New from Your Creators",
                        posts: feed,
                        campaignFor: { vm.campaign(for: $0) },
                        onNearEnd: { post in
                            Task { await vm.loadMoreHomeFeed(current: post) }
                        },
                        onPlay: onPlayPost,
                        focusFirstCardOnEntry: focusFirstShelfCard
                    )
                }

                if !continueWatching.isEmpty {
                    Shelf(
                        title: "Continue Watching",
                        posts: continueWatching,
                        campaignFor: { vm.campaign(for: $0) },
                        onPlay: onPlayPost
                    )
                }

                if !recentCollectionCards.isEmpty {
                    CollectionShelf(
                        title: "Continue Collection",
                        cards: recentCollectionCards,
                        onPlayCollection: onPlayCollection
                    )
                }

                ForEach(creatorRows) { row in
                    Shelf(
                        title: row.campaign.attributes.name ?? "Creator",
                        posts: row.posts,
                        campaignFor: { _ in row.campaign },
                        onNearEnd: { post in
                            Task { await vm.loadMoreCreatorRow(campaignID: row.id, current: post) }
                        },
                        headerLink: .creator(id: row.campaign.id),
                        headerAvatarURL: row.campaign.attributes.bestAvatarURL,
                        onPlay: onPlayPost
                    )
                }
            }
            .padding(.bottom, 40)
        }
        .scrollClipDisabled()   // tvOS 17+ — lets focused-card scale escape ScrollView bounds
    }

    /// Creator rows with content, honoring the mature-content gate.
    private var creatorRows: [HomeViewModel.CreatorRow] {
        vm.creatorRows.filter { row in
            guard !row.posts.isEmpty else { return false }
            if prefs.showMatureContent { return true }
            return row.campaign.attributes.isNSFW != true
        }
    }
}

struct EmptyFeedView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 80))
                .foregroundStyle(PatreonColors.secondaryText)
            Text("Nothing here yet")
                .font(.title2)
                .foregroundStyle(PatreonColors.primaryText)
            Text("Support a creator on Patreon to see their posts here.")
                .foregroundStyle(PatreonColors.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            Text(message)
                .font(.title3)
                .foregroundStyle(PatreonColors.primaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 800)
            Button("Try Again", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
