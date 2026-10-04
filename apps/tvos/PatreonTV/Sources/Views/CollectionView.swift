//
//  CollectionView.swift
//  PatreonTV
//
//  One collection: its title/description/art plus the posts it contains, with a
//  Newest/Oldest toggle.
//
//  Patreon returns a collection's posts *whole* from
//  `/api/collection/{id}?include=posts` (the `filter[collection_id]` posts
//  endpoint ignores the filter and returns the whole campaign).
//

import Observation
import SwiftUI

struct CollectionView: View {

    let collectionID: String
    /// Post to focus on open (set by "In this collection"). Falls back to the
    /// last episode played, then the first post.
    var focusPostID: String? = nil
    var onPlayPost: ((String) -> Void)? = nil

    @State private var vm: CollectionViewModel
    @State private var reversed = false

    init(collectionID: String, focusPostID: String? = nil, onPlayPost: ((String) -> Void)? = nil) {
        self.collectionID = collectionID
        self.focusPostID = focusPostID
        self.onPlayPost = onPlayPost
        // Seed from the cache so returning to the screen is instant.
        _vm = State(initialValue: CollectionViewModel(collectionID: collectionID))
    }
    /// Initial focus lands on the last episode played (if any), else the first
    /// post. A pushed page otherwise leaves focus on the tab bar.
    @FocusState private var focusedPostID: String?

    private let columns = [GridItem(.adaptive(minimum: 400, maximum: 480), spacing: 32)]

    var body: some View {
        Group {
            switch vm.state {
            case .loading:
                ProgressView().controlSize(.large)
            case .error(let message):
                ErrorView(message: message) {
                    Task { await vm.load(collectionID: collectionID) }
                }
            case .loaded:
                content
            }
        }
        .task { await vm.load(collectionID: collectionID) }
        .onDisappear {
            // Record on the way out: updating the store re-renders Home, and
            // doing that mid-push stole the initial focus.
            recordRecent()
        }
        .background(PatreonColors.background.ignoresSafeArea())
    }

    private var content: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 40) {
                    header
                    postsToolbar
                    postsGrid
                }
                .padding(.top, 60)
                .padding(.bottom, 60)
            }
            .scrollClipDisabled()
            .task { await focusInitialPost(using: proxy) }
        }
    }

    /// Focus the post the user came for (from "In this collection"), else the
    /// last episode played, else the first post. The grid is lazy, so a deep cell
    /// isn't realized until it's on screen and focus can't move to a cell that
    /// doesn't exist yet — scroll it into view first, then move focus.
    private func focusInitialPost(using proxy: ScrollViewProxy) async {
        let requested = focusPostID.flatMap { id in
            vm.posts.contains { $0.id == id } ? id : nil
        }
        guard let target = requested
                ?? PlaybackProgressStore.shared.mostRecent(in: vm.posts.map(\.id))?.postID
                ?? vm.posts.first?.id
        else { return }
        try? await Task.sleep(for: .milliseconds(250))
        proxy.scrollTo(target, anchor: .center)
        try? await Task.sleep(for: .milliseconds(350))
        focusedPostID = target
    }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .top, spacing: 32) {
            CollectionArtwork(urls: [vm.collection?.attributes.thumbnail?.bestImageURL], iconSize: 48)
                .frame(width: 280, height: 280)
                .background(PatreonColors.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 12) {
                Text(vm.collection?.attributes.title ?? "Collection")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(PatreonColors.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)

                if let description = vm.collection?.attributes.description, !description.isEmpty {
                    Text(description)
                        .font(.title3)
                        .foregroundStyle(PatreonColors.secondaryText)
                        .lineLimit(4)
                }

                if let total = vm.collection?.attributes.numPosts {
                    Text("\(total) posts")
                        .font(.subheadline)
                        .foregroundStyle(PatreonColors.tertiaryText)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 60)
    }

    private var postsToolbar: some View {
        HStack {
            Text("Posts")
                .font(.title2.weight(.semibold))
                .foregroundStyle(PatreonColors.primaryText)
            Spacer()
            Button {
                reversed.toggle()
            } label: {
                Label(reversed ? "Oldest first" : "Newest first", systemImage: "arrow.up.arrow.down")
                    .font(.title3.weight(.medium))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(reversed ? "Oldest first" : "Newest first")
        }
        .padding(.horizontal, 60)
        .focusSection()
    }

    @ViewBuilder
    private var postsGrid: some View {
        LazyVGrid(columns: columns, spacing: 40) {
            ForEach(displayedPosts) { post in
                NavigationLink(value: DeepLinkDestination.post(id: post.id, autoplay: false)) {
                    PostCard(post: post)
                }
                .buttonStyle(.card)
                .focused($focusedPostID, equals: post.id)
                .onPlayPauseCommand { onPlayPost?(post.id) }
                .id(post.id)
            }
        }
        .padding(.horizontal, 60)
        .focusSection()
    }

    private var displayedPosts: [Post] {
        reversed ? Array(vm.posts.reversed()) : vm.posts
    }

    /// Remember this collection so Home can offer it under Continue Collection.
    /// Only once the user has actually watched something in it — merely opening
    /// the collection shouldn't add it.
    private func recordRecent() {
        guard let collection = vm.collection else { return }
        guard vm.posts.contains(where: { PlaybackProgressStore.shared.progress(for: $0.id) != nil })
        else { return }

        RecentCollectionsStore.shared.record(RecentCollection(
            id: collection.id,
            title: collection.attributes.title ?? "Collection",
            squareImageURL: collection.attributes.thumbnail?.bestImageURL,
            wideImageURL: collection.attributes.thumbnail?.wideImageURL,
            numPosts: collection.attributes.numPosts
        ))
    }
}

// MARK: - View model

@MainActor
@Observable
final class CollectionViewModel {

    enum State: Equatable {
        case loading
        case loaded
        case error(String)
    }

    var state: State = .loading
    var collection: PatreonCollection?
    var posts: [Post] = []

    init(collectionID: String? = nil) {
        if let id = collectionID, let cached = CollectionPostsCache.shared.snapshot(for: id) {
            collection = cached.collection
            posts = cached.posts
            state = .loaded
        }
    }

    func load(collectionID: String) async {
        // Seeded from the cache (or already loaded): keep returning instant.
        guard collection == nil else { return }
        state = .loading
        do {
            let doc = try await PatreonClient.shared.collection(id: collectionID)
            collection = doc.data
            posts = doc.data.orderedPosts(from: doc.included ?? [])
            CollectionPostsCache.shared.store(collection: doc.data, posts: posts)
            state = .loaded
        } catch {
            state = .error((error as? PatreonError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
