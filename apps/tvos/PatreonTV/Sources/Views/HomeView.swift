//
//  HomeView.swift
//  PatreonTV
//
//  The couch-first landing screen: a vertical stack of horizontal shelves —
//  "Recent" first, then Continue Watching, Continue Collection,
//  and a row per creator.
//

import Combine
import SwiftUI

struct HomeView: View {

    @State private var vm = HomeViewModel()
    @State private var prefs = ContentPreferences.shared
    @Environment(\.scenePhase) private var scenePhase
    /// Whether Home is the visible tab. Combined with `scenePhase` to run the
    /// poll loop only while the user can actually see the feed.
    @State private var isVisible = false
    /// Pending shelf refresh after a post is marked watched. Cancelled and
    /// rescheduled while the store keeps changing, so the removal tracks the
    /// latest change.
    @State private var pendingContinueWatchingRefresh: Task<Void, Never>?

    /// Opens a post and starts playback immediately. Wired to the Siri Remote
    /// Play/Pause button on a focused card; a normal select still opens the
    /// detail screen. The second argument is the shelf's playback queue.
    var onPlayPost: (String, [String]?, AutoplaySource) -> Void = { _, _, _ in }
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
        .task(id: isRefreshActive) {
            guard isRefreshActive else { return }

            // Let the initial load finish before refreshing (the .task above
            // may still be in flight). If it failed, keep waiting so the
            // timer starts once the retry button succeeds.
            while !Task.isCancelled {
                if vm.state == .loaded || vm.state == .empty { break }
                try? await Task.sleep(for: .milliseconds(250))
            }
            guard !Task.isCancelled else { return }

            await vm.refreshIfStale(minInterval: ContentRefresh.foregroundMinInterval)

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(ContentRefresh.pollInterval))
                guard !Task.isCancelled else { return }
                await vm.refreshIfStale(minInterval: ContentRefresh.pollInterval)
            }
        }
        .background(PatreonColors.background.ignoresSafeArea())
        // Only membership/order changes matter here — not every progress tick.
        // Reading this in the body also registers the Observation dependency.
        .onChange(of: inProgressIDs) { _, _ in
            scheduleContinueWatchingRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .playbackDidFinish)) { _ in
            // Something finished (possibly while the player is still on screen
            // with autoplay off). Pull the newest stream in the background.
            Task { await vm.refresh() }
        }
        .onAppear {
            isVisible = true
            Task { await vm.refreshIfStale(minInterval: ContentRefresh.foregroundMinInterval) }

            // A video may have finished while Home was covered by the player.
            // Reconcile as soon as we're visible again instead of waiting for
            // the delayed change handler (which may already have fired).
            guard vm.state == .loaded,
                  vm.continueWatching.map(\.id) != inProgressIDs
            else { return }
            pendingContinueWatchingRefresh?.cancel()
            Task { await vm.refreshContinueWatching() }
        }
        .onDisappear {
            isVisible = false
            pendingContinueWatchingRefresh?.cancel()
        }
    }

    /// True while Home is the selected tab and the app is in the foreground.
    private var isRefreshActive: Bool {
        isVisible && scenePhase == .active
    }

    /// In-progress post IDs, most recent first — the Continue Watching
    /// signature. Position updates alone don't change it.
    private var inProgressIDs: [String] {
        PlaybackProgressStore.shared.inProgress().map(\.postID)
    }

    /// Rebuild the shelf immediately and let the 0.1s transition carry the
    /// removal (~100ms total). Rescheduling cancels the previous refresh.
    private func scheduleContinueWatchingRefresh() {
        pendingContinueWatchingRefresh?.cancel()
        pendingContinueWatchingRefresh = Task {
            guard !Task.isCancelled else { return }
            await vm.refreshContinueWatching()
        }
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
                        title: L10n.string("New"),
                        posts: feed,
                        campaignFor: { vm.campaign(for: $0) },
                        onNearEnd: { post in
                            Task { await vm.loadMoreHomeFeed(current: post) }
                        },
                        onPlay: onPlayPost,
                        // Every card in display order; the detail view skips
                        // finished/non-playable neighbors using the full post
                        // document, since shelf listing metadata can be
                        // incomplete (missing post_type / current_user_can_view).
                        playbackQueue: feed.map(\.id),
                        playbackSource: .new,
                        focusFirstCardOnEntry: focusFirstShelfCard
                    )
                }

                if !continueWatching.isEmpty {
                    Shelf(
                        title: L10n.string("Continue Watching"),
                        posts: continueWatching,
                        campaignFor: { vm.campaign(for: $0) },
                        onPlay: onPlayPost,
                        // Follow this shelf too: Up Next is the card to the
                        // right, not the creator's feed.
                        playbackQueue: continueWatching.map(\.id),
                        playbackSource: .continueWatching
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if !recentCollectionCards.isEmpty {
                    CollectionShelf(
                        title: L10n.string("Continue Collection"),
                        cards: recentCollectionCards,
                        onPlayCollection: onPlayCollection
                    )
                }

                ForEach(creatorRows) { row in
                    Shelf(
                        title: row.campaign.attributes.name ?? L10n.string("Creator"),
                        posts: row.posts,
                        campaignFor: { _ in row.campaign },
                        onNearEnd: { post in
                            Task { await vm.loadMoreCreatorRow(campaignID: row.id, current: post) }
                        },
                        headerLink: .creator(id: row.campaign.id),
                        headerAvatarURL: row.campaign.attributes.bestAvatarURL,
                        onPlay: onPlayPost,
                        playbackSource: .channels
                    )
                }
            }
            .padding(.bottom, 40)
            // Animate cards dropping out (or into) Continue Watching once the
            // delayed refresh lands.
            .animation(.easeInOut(duration: 0.1), value: continueWatching.map(\.id))
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
