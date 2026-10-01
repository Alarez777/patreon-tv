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

import NukeUI
import Observation
import SwiftUI

struct CollectionView: View {

    let collectionID: String
    var onPlayPost: ((String) -> Void)? = nil

    @State private var vm = CollectionViewModel()
    @State private var reversed = false

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
        .background(PatreonColors.background.ignoresSafeArea())
    }

    private var content: some View {
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
    }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .top, spacing: 32) {
            art
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

    @ViewBuilder
    private var art: some View {
        if let url = vm.collection?.attributes.thumbnail?.bestImageURL {
            LazyImage(url: url) { state in
                if let image = state.image {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    PatreonColors.cardSurface
                }
            }
        } else {
            ZStack {
                PatreonColors.cardSurface
                Image(systemName: "square.stack")
                    .font(.system(size: 48))
                    .foregroundStyle(PatreonColors.tertiaryText)
            }
        }
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
                .onPlayPauseCommand { onPlayPost?(post.id) }
            }
        }
        .padding(.horizontal, 60)
        .focusSection()
    }

    private var displayedPosts: [Post] {
        reversed ? Array(vm.posts.reversed()) : vm.posts
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

    func load(collectionID: String) async {
        state = .loading
        do {
            let doc = try await PatreonClient.shared.collection(id: collectionID)
            collection = doc.data

            // Posts arrive in `included`; order them by the collection's own
            // `post_ids` (the include order isn't exactly the custom order).
            let byID = Dictionary(
                (doc.included ?? []).compactMap { included -> (String, Post)? in
                    if case .post(let post) = included { return (post.id, post) }
                    return nil
                },
                uniquingKeysWith: { first, _ in first }
            )

            if let order = doc.data.attributes.postIDs, !order.isEmpty {
                posts = order.compactMap { byID[String($0)] }
            } else {
                posts = (doc.included ?? []).compactMap {
                    if case .post(let post) = $0 { return post }
                    return nil
                }
            }

            state = .loaded
        } catch {
            state = .error((error as? PatreonError)?.errorDescription ?? error.localizedDescription)
        }
    }
}
